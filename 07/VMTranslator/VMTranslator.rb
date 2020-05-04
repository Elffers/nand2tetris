require_relative 'parser'
require_relative 'codewriter'

class VMTranslator
  attr_accessor :filenames, :writer, :is_dir

  def initialize input
    @filenames = filenames_from input
    @writer = CodeWriter.new(output_for input)
    @is_dir = is_dir? input
  end

  def is_dir? input
    File.directory? input
  end

  def self.run input
    vm = VMTranslator.new(input)
    p filenames: vm.filenames
    # p output: vm.writer.output.path
    vm.translate
  end

  def filenames_from input
    if File.directory? input
      pattern = File.join input, "*.vm"
      files = Dir.glob(pattern)
      sys = files.delete "#{input}/Sys.vm"
      if sys
        files = files.unshift(sys) # puts Sys.vm file in front
      end
      files
    else
      [input]
    end
  end

  def output_for input
    # take into account "."
    if File.directory? input
      full_path = File.expand_path input
      output_file = File.basename(full_path) + ".asm"
      File.join full_path, output_file

      # elsif Dir.exist?("../#{input}") && Dir.pwd == File.expand_path("../#{input}")
      #   full_path = File.expand_path input
      #   File.basename(full_path) + ".asm"
    else
      input.sub("vm", "asm")
    end
  end

  def translate
    if is_dir
      writer.writeInit
      writer.writeCall("Sys.init", 0)
    end

    filenames.each do |f|
      File.open(f) do |io|
        p = Parser.new(io)
        process_file p
      end
    end
  end

  def process_file parser
    while parser.hasMoreCommands
      parser.advance
      cmd = parser.current_cmd

      p cmd # TODO: Remove

      arg1 = parser.arg1
      arg2 = parser.arg2

      case parser.commandType

      when "C_ARITHMETIC"
        writer.writeArithmetic cmd
      when "C_PUSH"
        writer.writePush arg1, arg2
      when "C_POP"
        writer.writePop arg1, arg2

      when "C_LABEL" # Branching commands
        writer.writeLabel arg1
      when "C_GOTO"
        writer.writeGoto arg1
      when "C_IF"
        writer.writeIf arg1

      when "C_CALL" # Function commands
        writer.writeCall arg1, arg2
      when "C_RETURN"
        writer.writeReturn
      when "C_FUNCTION"
        writer.writeFunction arg1, arg2
      end
    end
  end
end

if $0 == __FILE__
  VMTranslator.run(ARGV[0])
end
