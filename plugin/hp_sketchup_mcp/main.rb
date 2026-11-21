# HP SketchUp MCP - phan chinh
# Cong dung : May chu TCP nho chay ben trong SketchUp (chi nghe 127.0.0.1:9876).
#             Server MCP (Python) gui lenh dang JSON 1 dong, SketchUp thuc hien
#             tren luong chinh (qua UI.start_timer) va tra ket qua JSON 1 dong.
# Cach dung : Tu khoi dong khi mo SketchUp. Menu Extensions > HP MCP > Bat/Tat/Trang thai.
# Ngay viet : 2026-11-11 (ban 1.1.0: 2026-11-21, ho tro SketchUp 2017-2025)
require 'socket'
require 'json'
require 'stringio'
require 'tmpdir'

module HP
  module SketchUpMCP
    VERSION = '1.1.0'.freeze
    HOST    = '127.0.0.1'.freeze   # chi cho phep ket noi tu chinh may nay
    PORT    = 9876
    MAX_OUT = 60_000               # gioi han do dai chuoi tra ve

    @server  = nil
    @timer   = nil
    @clients = {}
    @busy    = false

    class << self
      # ---------- Bat / tat may chu ----------
      def start
        return true if @server
        @server = TCPServer.new(HOST, PORT)
        @timer  = UI.start_timer(0.1, true) { poll }
        puts "[HP MCP] Dang nghe tai #{HOST}:#{PORT}"
        true
      rescue StandardError => e
        @server = nil
        puts "[HP MCP] Khong mo duoc cong #{PORT}: #{e.message}"
        false
      end

      def stop
        UI.stop_timer(@timer) if @timer
        @timer = nil
        @clients.each_key { |c| c.close rescue nil }
        @clients.clear
        @server.close if @server
        @server = nil
        puts '[HP MCP] Da tat'
      end

      def running?
        !@server.nil?
      end

      # ---------- Vong doc du lieu (chay tren luong chinh) ----------
      def poll
        return if @busy || @server.nil?
        @busy = true
        accept_new
        @clients.keys.each { |c| read_client(c) }
      ensure
        @busy = false
      end

      def accept_new
        loop do
          c = @server.accept_nonblock
          @clients[c] = String.new
        end
      rescue IO::WaitReadable, Errno::EINTR
        nil
      end

      def read_client(c)
        closed = false
        begin
          loop { @clients[c] << c.read_nonblock(65_536) }
        rescue IO::WaitReadable
          nil
        rescue EOFError, IOError, SystemCallError
          closed = true
        end
        buf = @clients[c]
        while (i = buf.index("\n"))
          line = buf.slice!(0..i).strip
          next if line.empty?
          resp = handle_line(line)
          begin
            c.write(JSON.generate(resp) + "\n")
          rescue IOError, SystemCallError
            closed = true
            break
          end
        end
        return unless closed
        c.close rescue nil
        @clients.delete(c)
      end

      # ---------- Xu ly lenh ----------
      def handle_line(line)
        req = JSON.parse(line)
        id  = req['id']
        params = req['params'] || {}
        result =
          case req['method']
          when 'ping'       then ping
          when 'model_info' then model_info
          when 'eval_ruby'  then eval_ruby(params)
          when 'screenshot' then screenshot(params)
          else raise ArgumentError, "Lenh khong ho tro: #{req['method']}"
          end
        { 'id' => id, 'ok' => true, 'result' => result }
      rescue Exception => e # rubocop:disable Lint/RescueException
        { 'id' => (req && req['id']), 'ok' => false,
          'error' => "#{e.class}: #{e.message}",
          'backtrace' => (e.backtrace || [])[0, 8] }
      end

      def ping
        m = Sketchup.active_model
        { 'plugin' => VERSION, 'sketchup' => Sketchup.version, 'pro' => Sketchup.is_pro?,
          'model_title' => m ? m.title : nil, 'model_path' => m ? m.path : nil }
      end

      def model_info
        m  = Sketchup.active_model
        bb = m.bounds
        u  = m.options['UnitsOptions']
        to_mm = ->(v) { (v.to_f * 25.4).round(1) }
        {
          'title' => m.title, 'path' => m.path, 'modified' => m.modified?,
          'units' => { 'LengthUnit' => u['LengthUnit'], 'LengthFormat' => u['LengthFormat'],
                       'LengthPrecision' => u['LengthPrecision'] },
          'bounds_mm' => bb.empty? ? nil : { 'min' => bb.min.to_a.map(&to_mm), 'max' => bb.max.to_a.map(&to_mm) },
          'counts' => {
            'entities_top' => m.entities.size,
            'groups' => m.entities.grep(Sketchup::Group).size,
            'components' => m.entities.grep(Sketchup::ComponentInstance).size,
            'faces_top' => m.entities.grep(Sketchup::Face).size,
            'definitions' => m.definitions.size, 'materials' => m.materials.size
          },
          'tags' => m.layers.map(&:name),
          'scenes' => m.pages.map(&:name),
          'selection' => m.selection.size
        }
      end

      # Chay doan ma Ruby. Neu co 'operation' thi gom thanh 1 lan Undo
      # (tuong tu UNDO Begin/End trong AutoCAD).
      def eval_ruby(params)
        code = params['code'].to_s
        op   = params['operation']
        model = Sketchup.active_model
        out = StringIO.new
        old_stdout = $stdout
        $stdout = out
        model.start_operation(op.to_s, true) if op
        begin
          value = eval(code, eval_binding, '(claude)', 1) # rubocop:disable Security/Eval
          model.commit_operation if op
        rescue Exception # rubocop:disable Lint/RescueException
          model.abort_operation if op
          raise
        end
        { 'value' => serialize(value), 'stdout' => utf8(out.string)[0, MAX_OUT] }
      ensure
        $stdout = old_stdout if old_stdout
      end

      # Ep chuoi ve UTF-8 hop le (Ruby 2.2 cua SketchUp 2017 de loi ma hoa khi tao JSON)
      def utf8(s)
        s = s.dup.force_encoding('UTF-8')
        s.valid_encoding? ? s : s.scrub('?')
      end

      # Binding dung chung: bien local giu lai giua cac lan goi
      def eval_binding
        @eval_binding ||= TOPLEVEL_BINDING.eval('binding')
      end

      def serialize(v)
        case v
        when nil, true, false, Integer, Float then v
        when String then utf8(v)[0, MAX_OUT]
        when Array, Hash
          s = JSON.generate(v) rescue nil
          s && s.size <= MAX_OUT ? JSON.parse(s) : v.inspect[0, MAX_OUT]
        else v.inspect[0, MAX_OUT]
        end
      end

      # Chup anh khung nhin. view: current|iso|top|front|back|left|right
      def screenshot(params)
        model = Sketchup.active_model
        view  = model.active_view
        preset = (params['view'] || 'current').to_s
        set_camera(view, model, preset, params['perspective']) unless preset == 'current'
        view.zoom_extents if params.fetch('zoom_extents', preset != 'current')
        path = params['path'] || File.join(ENV['TEMP'] || Dir.tmpdir, "hp_su_#{Time.now.strftime('%H%M%S%L')}.png")
        ok = view.write_image(filename: path, width: (params['width'] || 1280).to_i,
                              height: (params['height'] || 800).to_i, antialias: true, transparent: false)
        raise 'write_image that bai' unless ok
        { 'path' => path }
      end

      def set_camera(view, model, preset, perspective)
        bb  = model.bounds
        tgt = bb.empty? ? ORIGIN : bb.center
        d   = [bb.diagonal, 1000.mm].max * 2
        dirs = {
          'iso'   => [-1, -1, 0.8], 'iso_back' => [1, 1, 0.8],
          'top'   => [0, 0, 1], 'front' => [0, -1, 0], 'back' => [0, 1, 0],
          'left'  => [-1, 0, 0], 'right' => [1, 0, 0]
        }
        v = Geom::Vector3d.new(*(dirs[preset] || dirs['iso'])).normalize
        eye = tgt.offset(v, d)
        up  = preset == 'top' ? Y_AXIS : Z_AXIS
        cam = Sketchup::Camera.new(eye, tgt, up)
        persp = perspective.nil? ? %w[iso iso_back].include?(preset) : perspective
        cam.perspective = persp
        view.camera = cam
      end
    end

    # ---------- Menu ----------
    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins').add_submenu('HP MCP')
      menu.add_item('Bat ket noi')  { start; UI.messagebox(running? ? "Dang nghe #{HOST}:#{PORT}" : 'Khong mo duoc cong') }
      menu.add_item('Tat ket noi')  { stop }
      menu.add_item('Trang thai')   { UI.messagebox(running? ? "HP MCP dang chay tai #{HOST}:#{PORT}" : 'HP MCP dang tat') }
      file_loaded(__FILE__)
      start
    end
  end
end
