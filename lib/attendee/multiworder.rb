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
== Multiworder
Mit der bisher beschriebenen Vorgehensweise werden die durch den Tokenizer erkannten 
Token aufgel�st und in Words verwandelt und �ber den Abbreviator und Decomposer auch 
Spezialf�lle behandelt, die einzelne W�rter betreffen. 
Um jedoch auch Namen wie z.B. John F. Kennedy als Sinneinheit erkennen zu k�nnen, muss
eine Analyse �ber mehrere Objekte erfolgen. Dies ist die Hauptaufgabe des Multiworders.
Der Multiworder analysiert die Teile des Datenstroms, die z.B. durch Satzzeichen oder 
weiteren Einzelzeichen (z.B. '(') begrenzt sind. Erkannte Mehrwortgruppen werden als 
zus�tzliches Objekt in den Datenstrom mit eingef�gt.

=== M�gliche Verlinkung
Erwartet:: Daten vom Typ *Word* z.B. von Wordsearcher, Decomposer, Ocr_variator, Multiworder
Erzeugt:: Daten vom Typ *Word* (mit Attribut WA_MULTIWORD). Je erkannter Mehrwortgruppe wird ein zus�tzliches Word-Objekt in den Datenstrom eingef�gt. Z.B. f�r Ocr_variator, Sequencer, Noneword_filter, Vector_filter

=== Parameter
Kursiv dargestellte Parameter sind optional (ggf. mit Angabe der Voreinstellung). 
Alle anderen Parameter m�ssen zwingend angegeben werden.
<b>in</b>:: siehe allgemeine Beschreibung des Attendee
<b>out</b>:: siehe allgemeine Beschreibung des Attendee
<b>source</b>:: siehe allgemeine Beschreibung des Dictionary
<b><i>mode</i></b>:: (Standard: all) siehe allgemeine Beschreibung des Dictionary
<b><i>stopper</i></b>:: (Standard: TA_PUNCTUATION, TA_OTHER) Gibt die Begrenzungen an, zwischen 
                        denen der Multiworder suchen soll, i.d.R. Satzzeichen und Sonderzeichen, 
                        weil sie kaum in einer Mehrwortgruppen vorkommen.

=== Beispiele
Bei der Verarbeitung einer normalen Textdatei mit der Ablaufkonfiguration <tt>t1.cfg</tt>
  meeting:
    attendees:
      - textreader:   { out: lines, files: '$(files)' }
      - tokenizer:    { in: lines, out: token }
      - abbreviator:   { in: token, out: abbrev, source: 'sys-abk' }
      - wordsearcher: { in: abbrev, out: words, source: 'sys-dic' }
      - decomposer:   { in: words, out: comps, source: 'sys-dic' }
      - multiworder:  { in: comps, out: multi, source: 'sys-mul' }
      - debugger:     { in: multi, prompt: 'out>' }
ergibt die Ausgabe �ber den Debugger: <tt>lingo -c t1 test.txt</tt>
  out> *FILE('test.txt')
  out> <Sein = [(sein/s), (sein/v)]>
  out> <Name = [(name/s)]>
  out> <ist = [(sein/v)]>
  out> <johann van siegen|MUL = [(johann van siegen/m)]>
  out> <Johann = [(johann/e)]>
  out> <van = [(van/w)]>
  out> <Siegen = [(sieg/s), (siegen/v), (siegen/e)]>
  out> :./PUNC:
  out> *EOL('test.txt')
  out> *EOF('test.txt')
=end


class Multiworder < BufferedAttendee

protected

  def init
    #  Parameter verwerten
    @stopper = get_array('stopper', TA_PUNCTUATION+','+TA_OTHER).collect {|s| s.upcase }
    
    #  W�rterbuch bereitstellen
    mul_src = get_array('source')
    mul_mod = get_key('mode', 'all')
    @mul_dic = Dictionary.new({'source'=>mul_src, 'mode'=>mul_mod}, @@library_config)

    #  Lexikalisierungs-W�rterbuch aus angegebenen Quellen ermitteln
    lex_src = nil
    mul_src.each { |src|
      this_src = @@library_config['databases'][src]['use-lex']
      if lex_src.nil? || lex_src==this_src
        lex_src = this_src
      else
        forward(STR_CMD_WARN, "Die Mehrwortw�rterb�cher #{mul_src.join(',')} sind mit unterschiedlichen W�rterb�chern lexikalisiert worden")
      end
    }
    @lex_dic = Dictionary.new({'source'=>lex_src.split(STRING_SEPERATOR_PATTERN), 'mode'=>'first'}, @@library_config)
    @lex_gra = Grammar.new({'source'=>lex_src.split(STRING_SEPERATOR_PATTERN), 'mode'=>'first'}, @@library_config)
    
    @number_of_expected_tokens_in_buffer = 3
    @eof_handling = false
  end


  def control(cmd, par)
    @mul_dic.report.each_pair { |key, value| set(key, value) } if cmd == STR_CMD_STATUS
    
    #  Jedes Control-Object ist auch Ausl�ser der Verarbeitung
    if cmd == STR_CMD_RECORD || cmd == STR_CMD_EOF
      @eof_handling = true
      while number_of_valid_tokens_in_buffer > 1
        process_buffer
      end 
      forward_number_of_token( @buffer.size, false )
      @eof_handling = false
    end
  end


  def process_buffer?
    number_of_valid_tokens_in_buffer >= @number_of_expected_tokens_in_buffer
  end

  
  def process_buffer
    unless @buffer[0].form == CHAR_PUNCT
      #  Pr�fe 3er Schl�ssel
      result = check_multiword_key( 3 )
      unless result.empty?
        #  3er Schl�ssel gefunden
        lengths = sort_result_len( result )
        unless lengths[0] > 3
          #  L�ngster erkannter Schl�ssel = 3
          create_and_forward_multiword( 3, result )
          forward_number_of_token( 3 )
          return
        else
          #  L�ngster erkannter Schl�ssel > 3, Buffer voll genug?
          unless @buffer.size >= lengths[0] || @eof_handling
            @number_of_expected_tokens_in_buffer = lengths[0]
            return
          else
            #  Buffer voll genug, Verarbeitung kann beginnen
            catch( :forward_one ) do
              lengths.each do |len|
                result = check_multiword_key( len )
                unless result.empty?
                  create_and_forward_multiword( len, result )
                  forward_number_of_token( len )
                  throw :forward_one
                end
              end
              
              #  Keinen Match gefunden
              forward_number_of_token( 1 )    
            end
            
            @number_of_expected_tokens_in_buffer = 3
            process_buffer if process_buffer?
            return
          end
        end
      end
      
      #  Pr�fe 2er Schl�ssel
      result = check_multiword_key( 2 )
      unless result.empty?
        create_and_forward_multiword( 2, result )
        forward_number_of_token( 1 )
      end
    end
      
    #  Buffer weiterschaufeln
    forward_number_of_token( 1, false )
    @number_of_expected_tokens_in_buffer = 3
  end        


private

  def create_and_forward_multiword( len, lexicals )

    #  Form aus Buffer auslesen und Teile markieren
    pos = 0
    form_parts = []
    begin
      if @buffer[pos].form == CHAR_PUNCT
        @buffer.delete_at( pos )
        form_parts[-1] += CHAR_PUNCT
      else
        @buffer[pos].attr = WA_UNKMULPART if @buffer[pos].attr == WA_UNKNOWN
        form_parts << @buffer[pos].form
        pos += 1
      end
    end while pos < len

    form = form_parts.join( ' ' )
    
    #  Multiword erstellen
    word = Word.new( form, WA_MULTIWORD )
    word << lexicals.collect { |lex| (lex.is_a?(Lexical)) ? lex : nil }.compact  # FIXME 1.60 - Ausstieg bei "*5" im Synonymer

    #  Forword Multiword
    forward( word )
  end

  
  #  Leitet 'len' Token weiter
  def forward_number_of_token( len, count_punc = true )
    begin
      unless @buffer.empty?
        forward( @buffer[0] )
        len -= 1 unless count_punc && @buffer[0].form == CHAR_PUNCT
        @buffer.delete_at( 0 )
      end
    end while len > 0
  end

  
  #  Ermittelt die maximale Ergebnisl�nge
  def sort_result_len( result )
    result.collect do |res|
      if res.is_a?( Lexical )
        res.form.split( ' ' ).size
      else
        res =~ /^\*(\d+)/
        $1.to_i
      end
    end.sort
  end
  
  
  #  Pr�ft einen definiert langen Schl�ssel ab Position 0 im Buffer
  def check_multiword_key( len )
    return [] if number_of_valid_tokens_in_buffer < len
    
    #  Wortformen aus der Wortliste auslesen
    sequence = @buffer.collect do |obj|
      if obj.kind_of?(StringA)
        next nil if obj.form == CHAR_PUNCT
        word = @lex_dic.find_word( obj.form )
        word = @lex_gra.find_compositum( obj.form ) if word.attr == WA_UNKNOWN
        (word.lexicals.size>0) ? word.lexicals[0].form : word.form
      else
        obj
      end
    end.compact
    #  Schl�ssel f�r Mehrwortw�rterbuch ermitteln
    key = sequence[0...len].join(' ').downcase
    @mul_dic.select( key )
  end


  #  Liefert die Anzahl g�ltiger Token zur�ck
  def number_of_valid_tokens_in_buffer
    @buffer.collect { |token| (token.form == CHAR_PUNCT) ? nil : 1 }.compact.size
  end
  
end
