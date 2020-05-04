require 'pp'

class Parser
  CMD = {
    C_ARITHMETIC: "C_ARITHMETIC",
    C_PUSH:       "C_PUSH",
    C_POP:        "C_POP",

    C_LABEL:      "C_LABEL",
    C_GOTO:       "C_GOTO",
    C_IF:         "C_IF",

    C_FUNCTION:   "C_FUNCTION",
    C_RETURN:     "C_RETURN",
    C_CALL:       "C_CALL"
  }

  attr_reader :current_cmd, :input

  def initialize input
    @input = input
  end

  def hasMoreCommands
    !input.eof?
  end

  def advance
    if hasMoreCommands
        cmd = input.gets
      until /^\w/ =~ cmd
        cmd = input.gets
      end
        cmd = cmd.split("//").first
        @current_cmd = cmd.strip
    else
      # p "EOF"
      @current_cmd = nil
    end
  end

  def commandType
    case
    when /^push/ =~ current_cmd
      CMD[:C_PUSH]
    when /^pop/ =~ current_cmd
      CMD[:C_POP]

    when /^label/ =~ current_cmd  # Branching commands
      CMD[:C_LABEL]
    when /^if/ =~ current_cmd
      CMD[:C_IF]
    when /^goto/ =~ current_cmd
      CMD[:C_GOTO]

    when /^call/ =~ current_cmd # Function commands
      CMD[:C_CALL]
    when /^function/ =~ current_cmd
      CMD[:C_FUNCTION]
    when /^return/ =~ current_cmd
      CMD[:C_RETURN]

    when current_cmd.nil?
      ""
    else
      CMD[:C_ARITHMETIC]
    end
  end

  def arg1
    current_cmd.split[1] if current_cmd
  end

  def arg2
    current_cmd.split[2] if current_cmd
  end

end
