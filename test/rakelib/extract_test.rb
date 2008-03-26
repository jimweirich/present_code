#!/usr/bin/env ruby

require 'test/unit'
require 'stringio'

require "rakelib/extract"
require 'flexmock/test_unit'

class FormatterTest < Test::Unit::TestCase
  def test_extract_literal
    ex = LiteralExtractor.new("variable_name")
    fmt = Formatter.new(ex)
    html = fmt.format
    assert_match(/\A<html>/i, html)
    assert_match(/<\/html>\Z/i, html)
    assert_match(/<head>\s*<style\s+type="text\/css"/, html)
    assert_match(/\.ruby \.ident/, html)
    assert_match(/variable_name/, html)
  end
end

class LiteralExtractorTest < Test::Unit::TestCase
  def test_extract_literal
    ex = LiteralExtractor.new("XYZ")
    assert_equal "XYZ", ex.extract
  end
end

class FileExtractorTest < Test::Unit::TestCase
  def test_extract_literal
    ex = FileExtractor.new("filename.rb")
    stream = flexmock("stream", :read => "XYZZY")
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }

    assert_equal "XYZZY", ex.extract
  end
end

class PatternExtractorTest < Test::Unit::TestCase
  FILE_CONTENTS = %{# Comment
    class SomeClass
      def another_method
        # Extra Method
      end
      def some_method(arg)
        if arg == 0
          x = 0
        end
      end
    end
    ## EXTRACT:A START
    class AnotherClass
      def some_method(arg)
        ## EXTRACT:A END
        # SECOND COPY
      end
    end\n}.gsub(/\n    /m, "\n")

  def test_extract_method
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method")
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "  def some_method(arg)\n    if arg == 0\n      x = 0\n    end\n  end\n",
      ex.extract
  end

  def test_extract_second_method
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method",
      :prematches => [/^\s*class AnotherClass/],
      :ignore => "## EXTRACT:")
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "  def some_method(arg)\n    # SECOND COPY\n  end\n",
      ex.extract
  end

  def test_extract_method_with_pre_window
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method",
      :preskip => 1)
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "    if arg == 0\n      x = 0\n    end\n  end\n",
      ex.extract
  end

  def test_extract_method_with_larger_pre_window
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method",
      :preskip => 2)
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "      x = 0\n    end\n  end\n",
      ex.extract
  end

  def test_extract_method_with_post_window
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method",
      :postskip => 1)
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "  def some_method(arg)\n    if arg == 0\n      x = 0\n    end\n",
      ex.extract
  end

  def test_extract_method_with_larger_post_window
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method",
      :postskip => 2)
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "  def some_method(arg)\n    if arg == 0\n      x = 0\n",
      ex.extract
  end

  def test_extract_method_with_pre_and_post_windows
    ex = PatternExtractor.new("filename.rb",
      :method => "some_method",
      :postskip => 2, :preskip => 2)
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "      x = 0\n",
      ex.extract
  end

  def test_extract_pattern
    ex = PatternExtractor.new("filename.rb",
      :start_pattern => "## EXTRACT:A START",
      :end_pattern => "## EXTRACT:A END", :window => 1)
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    assert_equal "class AnotherClass\n  def some_method(arg)\n",
      ex.extract
  end

  def test_extract_everything
    ex = PatternExtractor.new("filename.rb")
    stream = StringIO.new(FILE_CONTENTS)
    flexmock(ex).should_receive(:open).with("filename.rb", Proc).
      and_return { |fn, block| block.call(stream) }
    
    result = ex.extract
    assert_match(/\A# Comment/, result)
    assert_match(/end\n\Z/, result)
  end
end
