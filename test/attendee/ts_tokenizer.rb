require 'test/attendee/globals'

################################################################################
#
#    Attendee Tokenizer
#
class TestAttendeeTokenizer < Test::Unit::TestCase

  def test_basic
    @input = ["Dies ist ein Test."]
    @expect = [tk('Dies|WORD'), tk('ist|WORD'), tk('ein|WORD'), tk('Test|WORD'), tk('.|PUNC')]
    meet({})
  end


  def test_complex
    @input = ["1964 www.vorhauer.de bzw. nasenb�r, ()"]
    @expect = [
      tk('1964|NUMS'),
      tk('www.vorhauer.de|URLS'),
      tk('bzw|WORD'),
      tk('.|PUNC'),
      tk('nasenb�r|WORD'),
      tk(',|PUNC'),
      tk('(|OTHR'),
      tk(')|OTHR')
    ]
    meet({})
  end

end
#
################################################################################
