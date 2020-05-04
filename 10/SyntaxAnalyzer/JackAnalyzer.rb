#!/usr/bin/env ruby

require_relative 'CompilationEngine'

class JackAnalyzer
  def self.output_file_name file
    dir = File.dirname(file)
    base = File.basename(file, ".jack")+ ".xml"
    File.expand_path(dir + "/" + base)
  end

  def self.run input
    path = File.expand_path input
    input_files = []

    if File.directory? File.expand_path(path)
      jack_files = File.join(input, "*.jack")
      input_files = Dir.glob(jack_files)
    else
      input_files << path
    end

    input_files.each do |f|
      ce = CompilationEngine.new f
      ce.run
      output_file = output_file_name f
      File.write(output_file, ce.ast)
    end
  end
end

if $0 == __FILE__
  JackAnalyzer.run(ARGV[0])
end

