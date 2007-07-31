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
== Sequencer
Der Sequencer ist von seiner Funktion her �hnlich dem Multiworder. Der Multiworder 
nutzt zur Erkennung von Mehrwortgruppen spezielle W�rterb�cher, der Sequencer hingegen
definierte Folgen von Wortklassen. Mit dem Sequencer k�nnen Indexterme generiert werden,
die sich �ber mehrere W�rter erstrecken. 
Die Textfolge "automatische Indexierung und geniale Indexierung"
wird bisher in die Indexterme "automatisch", "Indexierung" und "genial" zerlegt.
�ber die Konfiguration kann der Sequencer Mehrwortgruppen identifizieren, die 
z.B. aus einem Adjektiv und einem Substantiv bestehen. Mit der o.g. Textfolge w�rde
dann auch "Indexierung, automatisch" und "Indexierung, genial" als Indexterm erzeugt
werden. Welche Wortklassenfolgen erkannt werden sollen und wie die Ausgabe aussehen 
soll, wird dem Sequencer �ber seine Konfiguration mitgeteilt.

=== M�gliche Verlinkung
Erwartet:: Daten vom Typ *Word* z.B. von Wordsearcher, Decomposer, Ocr_variator, Multiworder
Erzeugt:: Daten vom Typ *Word* (mit Attribut WA_SEQUENCE). Je erkannter Mehrwortgruppe wird ein zus�tzliches Word-Objekt in den Datenstrom eingef�gt. Z.B. f�r Ocr_variator, Sequencer, Noneword_filter, Vector_filter

=== Parameter
Kursiv dargestellte Parameter sind optional (ggf. mit Angabe der Voreinstellung). 
Alle anderen Parameter m�ssen zwingend angegeben werden.
<b>in</b>:: siehe allgemeine Beschreibung des Attendee
<b>out</b>:: siehe allgemeine Beschreibung des Attendee
<b><i>stopper</i></b>:: (Standard: TA_PUNCTUATION, TA_OTHER) Gibt die Begrenzungen an, zwischen 
                        denen der Sequencer suchen soll, i.d.R. Satzzeichen und Sonderzeichen, 
                        weil sie kaum in einer Mehrwortgruppen vorkommen.

=== Konfiguration
Der Sequencer ben�tigt zur Identifikation von Mehrwortgruppen Regeln, nach denen er 
arbeiten soll. Die ben�tigten Regeln werden nicht als Parameter, sondern in der 
Sprachkonfiguration hinterlegt, die sich standardm��ig in der Datei
<tt>de.lang</tt> befindet (YAML-Format).
  language:
    attendees:
      sequencer:
        sequences: [ [AS, "2, 1"], [AK, "2, 1"] ]
Hiermit werden dem Sequencer zwei Regeln mitgeteilt: Er soll Adjektiv-Substantiv- (AS) und 
Adjektiv-Kompositum-Folgen (AK) erkennen. Zus�tzlich ist angegeben, in welchem Format die
dadurch ermittelte Wortfolge ausgegeben werden soll. In diesem Beispiel also zuerst das 
Substantiv und durch Komma getrennt das Adjektiv.

=== Beispiele
Bei der Verarbeitung einer normalen Textdatei mit der Ablaufkonfiguration <tt>t1.cfg</tt>
  meeting:
    attendees:
      - textreader:   { out: lines, files: '$(files)' }
      - tokenizer:    { in: lines, out: token }
      - wordsearcher: { in: token, out: words, source: 'sys-dic' }
      - sequencer:    { in: words, out: seque }
      - debugger:     { in: seque, prompt: 'out>' }
ergibt die Ausgabe �ber den Debugger: <tt>lingo -c t1 test.txt</tt>
  out> *FILE('test.txt')
  out> <Lingo|?>
  out> <kann = [(koennen/v)]>
  out> <indexierung, automatisch|SEQ = [(indexierung, automatisch/q)]>
  out> <automatische = [(automatisch/a)]>
  out> <Indexierung = [(indexierung/s)]>
  out> <und = [(und/w)]>
  out> <indexierung, genial|SEQ = [(indexierung, genial/q)]>
  out> <geniale = [(genial/a), (genialisch/a)]>
  out> <Indexierung = [(indexierung/s)]>
  out> :./PUNC:
  out> *EOL('test.txt')
  out> *EOF('test.txt')
=end


class WordSequence
	attr_reader :classes, :format
private

	def initialize(wordclasses, format)
		@classes = wordclasses.upcase
		@format = format
	end

end


class Sequencer < BufferedAttendee

protected

	def init
		#	Parameter verwerten
		@stopper = get_array('stopper', TA_PUNCTUATION+','+TA_OTHER).collect {|s| s.upcase }
		@seq_strings = get_key('sequences')
		@seq_strings.collect! { |e| WordSequence.new(e[0], e[1]) }
		forward(STR_CMD_ERR, 'Konfiguration ist leer') if @seq_strings.size==0
	end


	def control(cmd, par)
		#	Jedes Control-Object ist auch Ausl�ser der Verarbeitung
		process_buffer
	end


	def process_buffer?
		@buffer[-1].kind_of?(StringA) && @stopper.include?(@buffer[-1].attr.upcase)
	end


	def process_buffer
		return if @buffer.size==0

		#	Sequence aus der Wortliste auslesen
		@sequence = @buffer.collect { |obj|
			res = '#'
			if obj.kind_of?(Word)
				lex = obj.lexicals[0]
				if obj.attr!=WA_UNKNOWN && obj.attr!=WA_UNKMULPART # && lex.attr!=LA_VERB
					res = lex.attr
				end
			end
			res
		}.join.upcase

		#		Muster erkennen
		@seq_strings.each { |wordseq|
			pos = 0
			until (pos = @sequence.index(wordseq.classes, pos)).nil?
				#	got a match
				inc('Anzahl erkannter Sequenzen')
				form = wordseq.format
				lexis = []
				(0...wordseq.classes.size).each { |j|
					lex = @buffer[pos+j].lexicals[0]
					form = form.gsub((j+1).to_s, lex.form)
					lexis << lex
				}
				word = Word.new(form, WA_SEQUENCE) << Lexical.new(form, LA_SEQUENCE)
				deferred_insert(pos, word)
				pos += 1
			end
		}	
		forward_buffer		
	end

end
