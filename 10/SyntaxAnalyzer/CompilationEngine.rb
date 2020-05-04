require_relative 'JackTokenizer'

class CompilationEngine
  attr_accessor :tokenizer, :depth, :ast, :current

  def initialize input
    @tokenizer = Tokenizer.new input
    @depth = 0
    @ast = ""
  end

  # 'class' className '{' classVarDec* subroutineDec* '}'
  def compile_class
    element "class" do
      token = get "class"
      output token

      # className identifier
      token = get
      parse_identifier token

      token = get "{"
      output token

      # classVarDec*
      while classVarDec? peek
        compile_class_var_dec
      end

      # subroutineDec*
      while subroutineDec? peek
        compile_subroutine
      end

      token = get "}"
      output token
    end
  end

  # ('static'|'field') type varName (',' varName)* ';'
  def compile_class_var_dec
    element "classVarDec" do
      # 'static' or 'field' keyword
      token = get
      output token

      token = get
      parse_type token

      # varName
      token = get
      parse_identifier token

      # handle optional varName args
      while peek.val == ","
        token = get ","
        output token

        # varName
        token = get
        parse_identifier token
      end

      token = get ";"
      output token
    end
  end

  # ('constructor' | 'function' | 'method') ('void' | type) subroutineName '('
  # parameterList ')' subroutineBody
  def compile_subroutine
    element "subroutineDec" do
      # 'constructor' | 'function' | 'method'
      token = get
      output token

      # 'void' | type
      token = peek
      if token.val == "void"
        token = get "void"
        output token
      else
        token = get
        parse_type token
      end

      # subroutineName
      token = get
      parse_identifier token

      token = get "("
      output token

      compile_parameter_list

      token = get ")"
      output token

      compile_subroutine_body
    end
  end

  # '{' varDec* statements '}'
  def compile_subroutine_body
    element "subroutineBody" do
      token = get "{"
      output token

      # varDec*
      while peek.val == "var"
        compile_var_dec
      end

      # statements
      compile_statements

      token = get "}"
      output token
    end
  end

  # 'var' type varName (',' varName)* ';'
  def compile_var_dec
    element "varDec" do
      token = get "var"
      output token

      token = get
      parse_type token

      # varName
      token = get
      parse_identifier token

      # handle optional varName args
      while peek.val == ","
        token = get ","
        output token

        # varName
        token = get
        parse_identifier token
      end

      token = get ";"
      output token
    end
  end

  # statement*
  def compile_statements
    element "statements" do

      loop do
        token = peek

        case token.val
        when "let"
          compile_let_statement
        when "if"
          compile_if_statement
        when "while"
          compile_while_statement
        when "do"
          compile_do_statement
        when "return"
          compile_return_statement
        else
          break
        end
      end

    end
  end

  # 'let' varName ('[' expression ']')? '=' expression ';'
  def compile_let_statement
    element "letStatement" do

      token = get "let"
      output token

      # varName
      token = get
      parse_identifier token

      # should be "[" or "="
      token = peek

      # ('[' expression ']')?
      if token.val == "["
        token = get "["
        output token

        compile_expression

        token = get "]"
        output token

        token = peek
      end

      if token.val == "="
        token = get "="
        output token
      end

      compile_expression

      token = get ";"
      output token

    end
  end

  # 'if' '(' expression ')' '{' statements '}' ('else') '{' statements '}')?
  def compile_if_statement
    element "ifStatement" do

      token = get "if"
      output token

      token = get "("
      output token

      compile_expression

      token = get ")"
      output token

      token = get "{"
      output token

      compile_statements

      token = get "}"
      output token

      # handle optional else clause
      if peek.val == "else"
        token = get "else"
        output token

        token = get "{"
        output token

        compile_statements

        token = get "}"
        output token
      end

    end
  end

  # 'while' '(' expression ')' '{' statements '}'
  def compile_while_statement
    element "whileStatement" do

      token = get "while"
      output token

      token = get "("
      output token

      compile_expression

      token = get ")"
      output token

      token = get "{"
      output token

      compile_statements

      token = get "}"
      output token

    end
  end

  # 'do' subroutineCall ';'
  def compile_do_statement
    element "doStatement" do

      token = get "do"
      output token

      # should be subroutine call
      # HACK: should be subroutineName, className, or varName consume first
      # identifier to make compile_subroutine_call reusable in compile_term
      token = get
      parse_identifier token

      compile_subroutine_call

      token = get ";"
      output token

    end
  end

  # 'return' expression? ';'
  def compile_return_statement
    element "returnStatement" do

      token = get "return"
      output token

      # expression?
      token = peek
      if token.val != ";"
        compile_expression
      end

      token = get ";"
      output token

    end
  end

  # ((type varName)(',' type varName)*)?
  def compile_parameter_list
    element "parameterList" do

      if peek.val != ")" # account for empty param list
        token = get
        parse_type token

        # varName
        token = get
        parse_identifier token

        # handle optional varName args
        while peek.val == ","
          token = get ","
          output token

          token = get
          parse_type token

          # varName
          token = get
          parse_identifier token
        end
      end

    end
  end

  # term (op term)*
  def compile_expression
    # NOTE hack for empty expression lists
    return if peek.val == ")"

    element "expression" do

      # term
      compile_term

      # (op term)*
      while peek.is_op?
        # op
        token = get
        output token

        # term
        compile_term
      end

    end
  end

  # integerConstant | stringConstant | keywordConstant | varName |
  # unaryOp term |
  # '(' expression ')' |
  # varName '[' # expression ']' | subroutineCall
  def compile_term
    element "term" do

      token = peek

      case
      when token.type == "integerConstant"
        token = get
        output token

      when token.type == "stringConstant"
        token = get
        output token

      when token.type == "keyword"
        token = get
        output token

      when token.is_unary_op?
        token = get
        output token

        compile_term

      when token.val == "("
        token = get "("
        output token

        compile_expression

        token = get ")"
        output token

        # varName | varName '[' expression ']' |  subroutineCall
        # NOTE if subroutineCall, next token would either be '(' or '.'
      when token.type == "identifier"
        token = get
        parse_identifier token # if varName, we're done

        # '[' expression ']'
        if peek.val == "["
          token = get "["
          output token

          compile_expression

          token = get "]"
          output token

          # subroutineCall
        elsif peek.val == "(" || peek.val == "."
          compile_subroutine_call
        end

      else
        # FIXME?
        @depth -= 1
        self.ast += "#{tabs}</term>\n"
        return
      end

    end
  end

  # (expression(',' expression)*)?
  def compile_expression_list
    element "expressionList" do

      compile_expression

      # handle optional expression elements
      while peek.val == ","
        token = get ","
        output token

        compile_expression
      end

    end
  end

  # subroutineName '(' expressionList ')' |
  # (className | varName) '.' subroutineName '(' expressionList ')'
  # NOTE first token (subroutineName) should have already been consumed
  def compile_subroutine_call
    # should be symbol '(' or '.'
    token = peek

    # '(' expressionList ')'
    if token.val == "("
      token = get "("
      output token

      compile_expression_list

      token = get ")"
      output token
    end

    # '.' subroutineName '(' expressionList ')'
    if token.val == "."
      token = get "."
      output token

      # subroutineName
      token = get
      parse_identifier token

      # '(' expressionList ')'
      token = get "("
      output token

      compile_expression_list

      token = get ")"
      output token
    end
  end

  #############
  #  Helpers  #
  #############
  def peek
    if @current
      @current
    else
      @current = tokenizer.advance
    end
  end

  def get(expected=nil)
    token =
      if @current
        token = @current
        @current = nil
        token
      else
        tokenizer.advance
      end

    if expected && token.val != expected
      raise "error: parse error on token: #{token.inspect}"
    end
    token
  end

  def tabs
    "\s\s" * @depth
  end

  def output token
    self.ast += "#{tabs}#{token}"
  end

  def parse_type token
    if token.type == "identifier"
      output token
    elsif token.val == "int" || token.val == "boolean" || token.val == 'char'
      output token
    else
      raise "error: parse error on token: #{token.inspect}"
    end
  end

  # used for className, subroutineName, and varName
  def parse_identifier token
    if token.type != "identifier"
      raise "error: parse error on token: #{token.inspect}"
    end
    output token
  end

  def element element
    self.ast += "#{tabs}<#{element}>\n"
    self.depth += 1

    yield

    self.depth -= 1
    self.ast += "#{tabs}</#{element}>\n"
  end

  def classVarDec? token
    token.val == "static" || token.val == "field"
  end

  def subroutineDec? token
    keywords = %w[constructor function method]
    keywords.include? token.val
  end

  def run
    compile_class
  rescue
    puts ast
    raise
  end
end

if $0 == __FILE__
  ce = CompilationEngine.new(ARGV[0])
  ce.run
  puts ce.ast
end
