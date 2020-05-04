require 'pp'
require 'fileutils'
require 'strscan'

class Tokenizer
  attr_accessor :filename, :current, :scanner, :tokens

  # Regexes used for token matching
  KEYWORDS = /
    class       |
    constructor |
    function    |
    method      |
    field       |
    static      |
    var         |
    int         |
    char        |
    boolean     |
    void        |
    true        |
    false       |
    null        |
    this        |
    let         |
    do          |
    if          |
    else        |
    while       |
    return      /x

  SYMBOLS = /[\{\}\(\)\[\]\.,;\+\-\*\/\&\|<>=~]/

  # A decimal number in the range 0 ..32767
  INTEGER_CONSTANT = /\d+/

  # '" A sequence of Unicode charcters not including double quote or newline
  # '"'
  STRING_CONSTANT = /"[^"\n]*"/

  # A sequence of letters, digits and underscore not starting with a digit
  IDENTIFIER = /[A-Z_]\w*/i

  # // comments to end of line
  # /* comment until closing */
  # /** API doc comment */
  COMMENTS = /
  \/\/ .+? $       |
  \/\* .+? \*\/    |
  \/\*\* .+? \*\/  /xm

  TOKEN_TYPE = {
    keyword: "keyword",
    symbol: "symbol",
    identifier: "identifier",
    int_const: "integerConstant",
    string_const: "stringConstant"
  }

  def initialize filename
    if File.extname(filename) != ".jack"
      p "not a jack file"
    end
    @filename = filename
    input = File.read filename
    @scanner = StringScanner.new(input)
    @tokens = []
  end

  def hasMoreTokens
    !@scanner.eos?
  end

  # Returns the current token, pushes it onto list of tokens
  def advance
    token = nil

    loop do # mechanism for skipping comments/whitespace
      return unless hasMoreTokens
      case
      when scanner.scan(COMMENTS)
        next
      when scanner.scan(/\s+/)
        next
      when scanner.scan(SYMBOLS)
        type = TOKEN_TYPE[:symbol]
      when scanner.scan(KEYWORDS)
        type = TOKEN_TYPE[:keyword]
      when scanner.scan(INTEGER_CONSTANT)
        type = TOKEN_TYPE[:int_const]
      when scanner.scan(STRING_CONSTANT)
        type = TOKEN_TYPE[:string_const]
      when scanner.scan(IDENTIFIER)
        type = TOKEN_TYPE[:identifier]
      else
        puts "error: #{scanner.rest}"
      end

      val = scanner.matched

      # Special handling of <, >, and &
      case val
      when "<"
        val = "&lt;"
      when ">"
        val = "&gt;"
      when "&"
        val = "&amp;"
      end

      # get rid of surrounding quotes for string constants
      if type == TOKEN_TYPE[:string_const]
        val.delete!('"')
      end

      if type == TOKEN_TYPE[:int_const] && val.to_i > 32767
        puts "error: integer out of range"
        return
      end

      pos = scanner.pos - scanner.matched.size

      token = Token.new(type, val, pos)
      self.tokens << token
      @current = token
      break
    end

    @current
  end

  def outputFilename
    dir = File.dirname(@filename) + "/test"
    FileUtils.mkdir_p dir
    base = File.basename(@filename, ".jack")+ "T.xml"
    dir + "/" + base
  end

  def output
    data = "<tokens>\n"
    while token = advance
      data += token.inspect
    end
    data += "</tokens>"

    out = File.write(File.expand_path(outputFilename), data)
    out
  end

  def tokenType
    @current.tokenType
  end

  def keyword
    if current.type == TOKEN_TYPE[:keyword]
      current.val
    else
      puts "Not valid for type #{current.type}"
    end
  end

  def intVal
    if current.type == TOKEN_TYPE[:int_const]
      current.val
    else
      puts "Not valid for type #{current.type}"
    end
  end

  def stringVal
    if current.type == TOKEN_TYPE[:string_const]
      current.val
    else
      puts "Not valid for type #{current.type}"
    end
  end

  def identifier
    if current.type == TOKEN_TYPE[:identifier]
      current.val
    else
      puts "Not valid for type #{current.type}"
    end
  end

  def symbol
    if current.type == TOKEN_TYPE[:symbol]
      current.val
    else
      puts "Not valid for type #{current.type}"
    end
  end

  class Token
    attr_accessor :type, :val, :pos

    def initialize type, val, pos
      @type = type
      @val = val
      @pos = pos
    end

    def is_op?
     ops = %w[+ - * / | &amp; &lt; &gt; =]
     ops.include? self.val
    end

    def is_unary_op?
      ops = %w[- ~]
      ops.include? self.val
    end

    def to_s
      "<#{type}> #{val} </#{type}>\n"
    end

    def inspect
      "[type: #{type}, val: #{val}, pos: #{pos}]"
    end
  end
end

if $0 == __FILE__
  t = Tokenizer.new(ARGV[0])
  t.output
end
