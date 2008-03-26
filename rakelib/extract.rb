#!/usr/bin/env ruby

require 'syntax/convertors/html'

class LineNumberFilter
  def initialize(every=1, sep='  ')
    @every = every
    @sep = sep
  end
  def filter(text)
    n = 0
    text.split("\n").collect { |ln|
      n += 1
      if (n % @every == 0)
        no = "%3d#{@sep}  " % n
      else
        no = "   #{@sep}  "
      end
      "<span class=\"linenumber\">#{no}</span>#{ln}"
    }.join("\n")
  end
end

class Styler
  def style
    %(<style type="text/css">
.ruby { font-size: 24pt; font-weight: bold; }
.ruby .normal {}
.ruby .linenumber { color: #aaa; font-style: italic; font-size: 16pt; }
.ruby .comment { color: #888; font-style: italic; }
.ruby .keyword { color: #A00; font-weight: bold; }
.ruby .method { color: #077; }
.ruby .class { color: #074; }
.ruby .module { color: #050; }
.ruby .punct { color: #447; font-weight: bold; }
.ruby .symbol { color: #099; }
.ruby .string { color: #944; }
.ruby .char { color: #F07; }
.ruby .ident { color: #004; }
.ruby .constant { color: #07F; }
.ruby .regex { color: #B66; }
.ruby .number { color: #D55; }
.ruby .attribute { color: #377; }
.ruby .global { color: #3B7; }
.ruby .expr { color: #227; }
</style>)
  end
end

class LiteralExtractor
  def initialize(literal_text)
    @literal_text = literal_text
  end
  def extract
    @literal_text
  end
end

class FileExtractor
  def initialize(file_name)
    @file_name = file_name
  end
  def extract
    open(@file_name) { |f| f.read }
  end
end

class PatternExtractor
  class CustomRegexp
  end
  class NeverMatch < CustomRegexp
    def =~(str)
      false
    end
  end

  class AlwaysMatch < CustomRegexp
    def =~(str)
      true
    end
  end

  NEVER = NeverMatch.new
  ALWAYS = AlwaysMatch.new

  def initialize(file_name, options={})
    @file_name = file_name
    if options[:method]
      method_matching(options[:method])
    else
      patterns(options)
    end
    if options[:window]
      @preskip = options[:window]
      @postskip = options[:window] 
    else
      @preskip = options[:preskip] || 0
      @postskip = options[:postskip] || 0
    end
    @prematches = options[:prematches] || []
    @ignore = (regexify(options[:ignore] || NEVER))
  end

  def extract
    prefix = "XXXXX"
    state = :skipping
    result = []
    open(@file_name) do |f|
      while state != :done && line = f.gets
        case state
        when :copying
          append(result, line)
          state = :done if @end_pattern[line]
        when :skipping
          if !@prematches.empty?
            if line =~ @prematches.first
              @prematches.shift
            end
          elsif @start_pattern[line]
            prefix = $1
            state = :copying
            append(result, line)
          end
        end
      end
    end
    @postskip.times do result.pop end
    result.join("")
  end

  private

  def patterns(options)
    spat = regexify(options[:start_pattern] || ALWAYS)
    epat = regexify(options[:end_pattern] || NEVER)
    @start_pattern = lambda { |s| spat =~ s }
    @end_pattern = lambda { |s| s =~ epat }
  end

  def method_matching(method_name)
    prefix = "__XXXXXX__"
    @start_pattern = lambda { |s|
      match = (s =~ /^(\s*)def\s+#{method_name}/)
      prefix = $1 if match
      match
    }
    @end_pattern = lambda { |s| s =~ /^#{prefix}end/ }
  end

  def append(result, line)
    result << line if @preskip <= 0 &&  @ignore !~ line 
    @preskip -= 1
  end

  def regexify(pattern)
    case pattern
    when Regexp, CustomRegexp
      pattern
    else
      /#{pattern}/
    end
  end
end

class Formatter
  def initialize(extractor, styler=Styler.new)
    @extractor = extractor
    @styler = Styler.new
  end
  def convert
    convertor = Syntax::Convertors::HTML.for_syntax("ruby")
    formatted_code = convertor.convert(@extractor.extract)
    formatted_code.gsub(/<\/?pre>/, '')
  end
  def format
    filt = LineNumberFilter.new(5)
    formatted_code = filt.filter(convert)
    "<html><head>#{@styler.style}</head><body><pre class=\"ruby\">#{formatted_code}</pre></body></html>"
  end
end

def extract(outfile, infile)
  file outfile => infile do
    puts "Extracting #{outfile}"
    formatter = Formatter.new(FileExtractor.new(infile))
    open(outfile, "w") do |out|
      out.puts formatter.format
    end
  end
end
