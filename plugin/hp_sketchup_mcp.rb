# HP SketchUp MCP - file nap extension
# Cong dung : Mo cong ket noi 127.0.0.1:9876 de Claude dieu khien SketchUp qua MCP
# Ngay viet: 2026-11-11
require 'sketchup.rb'
require 'extensions.rb'

module HP
  module SketchUpMCP
    unless file_loaded?(__FILE__)
      ext = SketchupExtension.new('HP SketchUp MCP', File.join(__dir__, 'hp_sketchup_mcp', 'main'))
      ext.version     = '1.1.0'
      ext.creator     = 'HP'
      ext.description = 'Ket noi Claude voi SketchUp qua MCP (cong 127.0.0.1:9876). ' \
                        'Menu: Extensions > HP MCP.'
      Sketchup.register_extension(ext, true)
      file_loaded(__FILE__)
    end
  end
end
