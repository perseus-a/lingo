#  LINGO ist ein Indexierungssystem mit Grundformreduktion, Kompositumzerlegung, 
#  Mehrworterkennung und Relationierung.
#
#  Copyright (C) 2005  John Vorhauer
#
#  This program is free software; you can redistribute it and/or modify it under 
#  the terms of the GNU General Public License as published by the Free Software 
#  Foundation;  either version 2 of the License, or  (at your option)  any later
#  version.
#
#  This program is distributed  in the hope  that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
#  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#  You should have received a copy of the  GNU General Public License along with 
#  this program; if not, write to the Free Software Foundation, Inc., 
#  51 Franklin St, Fifth Floor, Boston, MA 02110, USA
#
#  For more information visit http://www.lex-lingo.de or contact me at
#  welcomeATlex-lingoDOTde near 50�55'N+6�55'E.
#
#  Lex Lingo rules from here on


=begin rdoc
== Wordsearcher
Der Wordsearcher ist das Herzst�ck von Lingo. Er macht die Hauptarbeit und versucht 
alle Token die nach einem sinnvollen Wort aussehen, in den ihm angegebenen 
W�rterb�chern zu finden und aufzul�sen. Dabei werden die im W�rterbuch gefundenen
Grundformen inkl. Wortklassen an das Word-Objekt angeh�ngt.

=== M�gliche Verlinkung
Erwartet:: Daten vom Typ *Token* (andere werden einfach durchgereicht) z.B. von Tokenizer, Abbreviator
Erzeugt:: Daten vom Typ *Word* f�r erkannte W�rter z.B. f�r Synonymer, Decomposer, Ocr_variator, Multiworder, Sequencer, Noneword_filter, Vector_filter

=== Parameter
Kursiv dargestellte Parameter sind optional (ggf. mit Angabe der Voreinstellung). 
Alle anderen Parameter m�ssen zwingend angegeben werden.
<b>in</b>:: siehe allgemeine Beschreibung des Attendee
<b>out</b>:: siehe allgemeine Beschreibung des Attendee
<b>source</b>:: siehe allgemeine Beschreibung des Dictionary
<b><i>mode</i></b>:: (Standard: all) siehe allgemeine Beschreibung des Dictionary

=== Beispiele
Bei der Verarbeitung einer normalen Textdatei mit der Ablaufkonfiguration <tt>t1.cfg</tt>
  meeting:
    attendees:
      - textreader:   { out: lines, files: '$(files)' }
      - tokenizer:    { in: lines, out: token }
      - abbreviator:  { in: token, out: abbrev, source: 'sys-abk' }
      - wordsearcher: { in: abbrev, out: words, source: 'sys-dic' }
      - debugger:     { in: words, prompt: 'out>' }
ergibt die Ausgabe �ber den Debugger: <tt>lingo -c t1 test.txt</tt>
  out> *FILE('test.txt')
  out> <Dies = [(dies/w)]>
  out> <ist = [(sein/v)]>
  out> <ggf. = [(gegebenenfalls/w)]>
  out> <eine = [(einen/v), (ein/w)]> 
  out> <Abk�rzung = [(abk�rzung/s)]>
  out> :./PUNC:
  out> *EOL('test.txt')
  out> *EOF('test.txt')
=end

class Wordsearcher < Attendee

  def init
    #  W�rterbuch bereitstellen
    src = get_array('source')
    mod = get_key('mode', 'all')
    @dic = Dictionary.new({'source'=>src, 'mode'=>mod}, @@library_config)
  end


  def control(cmd, par)
    @dic.report.each_pair { |key, value|
      set(key, value) 
    } if cmd == STR_CMD_STATUS
  end


  def process(obj)
    if obj.is_a?(Token) && obj.attr == TA_WORD
      inc('Anzahl gesuchter W�rter')
      word = @dic.find_word(obj.form)
      inc('Anzahl gefundener W�rter') unless word.attr == WA_UNKNOWN
      obj = word
    end
    forward(obj)
  end

end