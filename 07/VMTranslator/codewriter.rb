class CodeWriter
  attr_reader :output
  attr_accessor :label, :static #, :ret_addr

  TEMP_BASE_ADDR = 5
  SEGMENTS = {
    "local"     => "LCL",
    "argument"  => "ARG",
    "this"      => "THIS",
    "that"      => "THAT",
  }

  def initialize filename
    @output = File.new("#{filename}", "w")  # /path/to/Foo.asm
    @label = 0 #increment, to ensure uniqueness of generated label names
    # @ret_addr = 0 #increment, to ensure uniqueness of generated return-address temp var
    @static = File.basename(filename, ".*") # Foo
  end

  def writeArithmetic cmd
    asm =
      case cmd
      when "not"
        not_asm
      when "neg"
        neg_asm
      when "add"
        add_asm
      when "sub"
        sub_asm
      when "eq"
        eq_asm
      when "gt"
        gt_asm
      when "lt"
        lt_asm
      when "and"
        and_asm
      when "or"
        or_asm
      end

    cmds = asm.join("\n")
    output.puts cmds
  end

  def writePush arg1, arg2
    asm =
      case arg1
      when "constant"
        push_const arg2
      when "static"
        push_static arg2
      when "pointer"
        push_pointer arg2
      when "temp"
        push_temp arg2
      else
        push_asm arg1, arg2
      end

    cmds = asm.join("\n")
    output.puts cmds
  end

  def writePop arg1, arg2
    asm =
      case arg1
      when "static"
        pop_static arg2
      when "pointer"
        pop_pointer arg2
      when "temp"
        pop_temp arg2
      else
        pop_asm arg1, arg2
      end

    cmds = asm.join("\n")
    output.puts cmds
  end

  ######################
  # Branching Commands #
  ######################

  def writeLabel label
    output.puts "(#{label})"
  end

  def writeIf label
    asm = if_goto_asm label
    cmds = asm.join("\n")
    output.puts cmds
  end

  def writeGoto label
    asm = goto_asm label
    cmds = asm.join("\n")
    output.puts cmds
  end

  ######################
  # Function Commands #
  ######################

  def writeCall function, n  # n = number of arguments
    asm = call_asm function, n
    cmds = asm.join("\n")
    output.puts cmds
  end

  def writeFunction function, locals
    self.static = function.split(".").first
    asm = function_asm function, locals
    cmds = asm.join("\n")
    output.puts cmds
  end

  def writeReturn
    asm = return_asm
    cmds = asm.join("\n")
    output.puts cmds
  end

  def writeInit
    asm = [
      "@256",
      "D=A",
      "@SP",
      "M=D"
    ]
    cmds = asm.join("\n")
    output.puts cmds
  end

  private

  #############################
  # Arithmetic/Logic Commands #
  ############################

  def eq_asm
    end_label = "END_EQ#{label}"
    eq_label = "EQ#{label}"
    self.label += 1
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')
      "D=M-D",  # D will be 0 if same as M

      "@#{eq_label}",
      "D;JEQ", # Jump to EQ if x == y

      "D=0", # Set D to false if x != y
      "@#{end_label}",
      "0;JMP",

      "(#{eq_label})",
      "D=-1", # Set D to true if x == y

      "(#{end_label})",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",
    ]
  end

  def gt_asm
    end_label = "END_EQ#{label}"
    gt_label = "GT#{label}"
    self.label += 1
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')
      "D=M-D",  # D will be 0 if same as M

      "@#{gt_label}",
      "D;JGT", # Jump to EQ if x == y

      "D=0", # Set D to false if x != y
      "@#{end_label}",
      "0;JMP",

      "(#{gt_label})",
      "D=-1", # Set D to true if x == y

      "(#{end_label})",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",
    ]
  end

  def lt_asm
    end_label = "LT_END_EQ#{label}"
    lt_label = "LT#{label}"
    self.label += 1
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')
      "D=M-D",  # D will be 0 if same as M

      "@#{lt_label}",
      "D;JLT", # Jump to LT if x < y

      "D=0", # Set D to false if x != y
      "@#{end_label}",
      "0;JMP",

      "(#{lt_label})",
      "D=-1", # Set D to true if x == y

      "(#{end_label})",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",
    ]
  end

  def and_asm
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')

      "M=M&D",  # x & y
      "@SP",
      "M=M+1"   # increment SP
    ]
  end

  def or_asm
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')
      "M=M|D",  # x & y
      "@SP",
      "M=M+1"   # increment SP
    ]
  end

  def add_asm
    # if y and x are next two values at top of stack, adds y to x
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')
      "M=M+D",  # adds y to x
      "@SP",
      "M=M+1"   # increment SP
    ]
  end

  def sub_asm
    # if y and x are next two values at top of stack, subtracts y from x
    [
      "@SP",
      "M=M-1",  # Decrement SP
      "A=M",    # go to first val at top of stack
      "D=M",    # store val in D
      "@SP",
      "M=M-1",  # decrement SP again
      "A=M",    # go to there ('x')
      "M=M-D",  # subtracts y from x
      "@SP",
      "M=M+1"   # increment SP
    ]
  end

  def not_asm
    # RAM[0] stores SP
    # @SP implies A=0 and M=whatever is in RAM[0]
    [
      "@SP",
      "D=M",
      "A=D-1", # set address of element we are going to "not"
      "M=!M"
    ]
  end

  def neg_asm
    [
      "@SP",
      "D=M",
      "A=D-1",
      "M=-M"
    ]
  end

  ##########################
  # Memory Access Commands #
  ##########################

  def push_const val
    [
      "@#{val}",
      "D=A",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1"
    ]
  end

  def push_temp i
    addr = TEMP_BASE_ADDR + i.to_i
   [
      "@#{addr}",
      "D=M",        # Store base address of memory segment in D
      "@SP",
      "A=M",        # Go to address stored in SP
      "M=D",        # Push value onto main stack
      "@SP",
      "M=M+1"       # Increment stack pointer
    ]
  end

  def push_pointer i
    seg = i == "0" ? "@THIS" : "@THAT"
    [
      seg,
      "D=M",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1"
    ]
  end

  def push_static i
    static_label = "@#{static}.#{i}"
    [
      static_label,
      "D=M",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1"
    ]
  end

  def push_asm seg, offset
    base = SEGMENTS[seg]
    [
      "@#{base}",
      "D=M",        # Store base address of memory segment in D
      "@#{offset}",
      "A=D+A",      # Go to offset from base address
      "D=M",        # Store value at offset in D

      "@SP",
      "A=M",        # Go to address stored in SP
      "M=D",        # Push value onto main stack
      "@SP",
      "M=M+1"       # Increment stack pointer
    ]
  end

  def pop_temp i
    addr = TEMP_BASE_ADDR + i.to_i
    [
      "@SP",
      "M=M-1",
      "A=M",
      "D=M",  # Store *SP (top of stack) in D
      "@#{addr}",
      "M=D",        # Push value onto main stack
    ]
  end

  def pop_pointer i
    seg = i == "0" ? "@THIS" : "@THAT"
    [
      "@SP",
      "M=M-1",
      "A=M",
      "D=M",  # Store *SP (top of stack) in D
      seg,
      "M=D"
    ]
  end

  def pop_static i
    static_label = "@#{static}.#{i}"
    [
      "@SP // start call to pop static #{i}",
      "M=M-1",
      "A=M",
      "D=M",  # Store *SP (top of stack) in D
      static_label,
      "M=D"
    ]
  end

  def pop_asm seg, offset
    base = SEGMENTS[seg]
    pop_label = "POP#{label}"
    self.label += 1
    [
      "@#{base} // start pop #{seg} #{offset}",
      "D=M",        # Store base address of memory segment in D
      "@#{offset}",
      "A=D+A",      # Go to offset from base address
      "D=A",        # Store addr to be written to in D
      "@#{pop_label}",         # TODO: POSSIBLE BUG - ENSURE UNIQUENESS?
      "M=D",        # store address to be written to at RAM[n] NOTE: Not sure if neessary?
      "@SP",
      "M=M-1",      # decrement SP
      "A=M",        # go to top of stack
      "D=M",        # Get value at top of stack
      "@#{pop_label}",
      "A=M",        # go to addd to be written to
      "M=D // end pop"
    ]
  end

  #####################
  # Function Commands #
  #####################

  def goto_asm label
    [
      "@#{label}",
      "0;JMP",
    ]
  end

  def if_goto_asm label
    [
      "@SP",
      "M=M-1",
      "A=M",
      "D=M",  # Pop top of stack, store value in D
      "@#{label}",
      "D;JNE"
    ]
  end

  def call_asm f, n
    return_label = "return-address#{label}"
    self.label += 1

    [
      # push return-address
      "@#{return_label} // start call to #{f}",
      "D=A",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",

      #push LCL
      "@LCL // writeCall: push LCL",
      "D=M",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",

      # push ARG
      "@ARG  // writeCall: push ARG",
      "D=M",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",

      # push THIS
      "@THIS // writeCall: push THIS",
      "D=M",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",

      # push THAT
      "@THAT // writeCall: push THAT",
      "D=M",
      "@SP",
      "A=M",
      "M=D",
      "@SP",
      "M=M+1",

      # ARG = SP-n-5
      "@5  // writeCall: ARG = SP-n",
      "D=A",
      "@#{n}",
      "D=D+A",
      "@SP",
      "D=M-D",
      "@ARG",
      "M=D",

      # LCL = SP
      "@SP // writeCall: LCL = SP",
      "D=M",
      "@LCL",
      "M=D",

      # goto f
      "@#{f} // goto #{f}",
      "0;JMP",

      # write return-address label
      "(#{return_label})  // end call to #{f}"
    ]
  end

  def function_asm f, k
    asm = []
    asm.push "(#{f})"

    i = 0
    while i < k.to_i
      asm.concat(push_const "0")
      i+=1
    end

    asm
  end

  def return_asm
    frame_label = "FRAME#{label}"
    ret_label = "RET#{label}"
    self.label += 1
    [
      # FRAME = LCL
      "@LCL // start return",
      "D=M",
      "@#{frame_label}", # FRAME = LCL base
      "M=D",

      # RET = *(FRAME - 5)
      "@5",
      "D=A",
      "@#{frame_label}",
      "D=M-D",
      "A=D",
      "D=M",
      "@#{ret_label}",
      "M=D",

      # *ARG = pop() # put return value where arg was (writes over args)
      "@SP",
      "M=M-1",
      "A=M",
      "D=M",
      "@ARG",
      "A=M",
      "M=D",

      # SP = ARG + 1
      "@ARG",
      "D=M+1",
      "@SP",
      "M=D",

      # THAT = *(FRAME - 1)
      "@1",
      "D=A",
      "@#{frame_label}",
      "D=M-D",
      "A=D",
      "D=M",
      "@THAT",
      "M=D",

      # THIS = *(FRAME - 2)
      "@2",
      "D=A",
      "@#{frame_label}",
      "D=M-D",
      "A=D",
      "D=M",
      "@THIS",
      "M=D",

      # ARG = *(FRAME - 3)
      "@3",
      "D=A",
      "@#{frame_label}",
      "D=M-D",
      "A=D",
      "D=M",
      "@ARG",
      "M=D",

      # LCL = *(FRAME - 4)
      "@4",
      "D=A",
      "@#{frame_label}",
      "D=M-D",
      "A=D",
      "D=M",
      "@LCL",
      "M=D",

      # goto RET
      "@#{ret_label}  // goto return address",
      "A=M",
      "0;JMP"
    ]
  end
end
