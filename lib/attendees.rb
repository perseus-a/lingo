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
== Attendee
Lingo ist als universelles Indexierungssystem entworfen worden. Seine St�rke liegt in der einfachen Konfigurierbarkeit f�r 
spezifische Aufgaben und in der schnelle Entwicklung weiterer Funktionen durch systematischen Kapselung der Komplexit�t auf
kleine Verarbeitungseinheiten. Die kleinste Verarbeitungseinheit wird Attendee genannt. Um ein gew�nschtes Verarbeitungsergebnis
zu bekommen, werden die ben�tigten Attendees einfach in einer Reihe hinter einander geschaltet. Ein einfaches Beispiel hierf�r ist
eine direkte Verbindung zwischen einem Textreader, einem Tokenizer und einem Textwriter. Alle drei Klassen sind von der Klasse
Attendee abgeleitet.

Der Textreader liest beispielsweise Zeilen aus einer Textdatei und leitet sie weiter an den Tokenizer. Der Tokenizer zerlegt eine
Textzeile in einzelne W�rter und gibt diese weiter an den Textwriter, der diese in eine (andere) Datei schreibt. �ber vielf�ltige 
Konfigurationsm�glichkeiten kann das Verhalten der Attendees an die eigenen Bed�rfnisse angepasst werden.

Die Verkettung einzelner Attendees findet �ber die Schnittstellen +listen+ und +talk+ statt. An +listen+ k�nnen beliebige Objekte 
zur Ver- und Bearbeitung �bergeben werden. Nach der Verarbeitung werden sie mittels +talk+ an die verketteten Attendees weiter 
gegeben. Objekte der Klasse AgendaItem dienen dabei der Steuerung der Verarbeitung und sind nicht Bestandteil der normalen 
Verarbeitung. Beispiele f�r AgendaItems sind die Kommandos TALK (Aufforderung zum Start der Verarbeitung), WARN (zur Ausgabe von 
Warnungen eines Attendees) und EOL (End of Line, Ende einer Textzeile nach Zerlegung in einzelne W�rter). Eine vollst�ndige 
�bersicht benutzer AgendaItems (oder auf Stream Commands) steht in lib/const.rb mit dem Prefix STR_CMD_.

Um die Entwicklung von neuen Attendees zu beschleunigen, wird durch die Vererbung sind bei wird die gesammte sind in der Regel nur 
drei abstrakte Methoden zu implementieren: +init+, +control+ und +process+. Die Methode +init+ wird bei der Instanziierung eines 
Objektes einmalig aufgerufen. Sie dient der Vorbereitung der Verarbeitung, z.B. durch das �ffnen und Bereitstellen von 
W�rterb�chern zur linguistischen Analyse. An die Methode +control+ werden alle eingehenden AgendaItems weitergeleitet. Dort erfolgt
die Verarbeitungssteuerung, also z.B. bei STR_CMD_FILE das �ffnen einer Datei und bei STR_CMD_EOF respektive das Schlie�en. Die 
echte Verarbeitung von Daten findet daher durch die Methode +process+ statt.

  
was macht attendee
- verkettung der attendees anhand von konfigurationsinformationen
- bereitstellung von globalen und spezifischen konfigurationsinformationen 
- behandlung von bestimmten �bergreifenden Kommandos, z.B. STR_CMD_TALK, STR_CMD_STATUS, STR_CMD_WARN, STR_CMD_ERR
- separierung und routing von kommando bzw. datenobjekten

was macht die abgeleitet klasse
- verarbeitet und/oder transformiert datenobjekte
- wird gesteuert durch kommandos
- schreibt verarbeitungsstatistiken

=end


require 'lib/modules'
require 'lib/language'
require 'lib/const'
require 'lib/types'


class Attendee
	include Reportable

	@@library_config = nil

private

	def initialize(config)
		init_reportable

		begin
			@@library_config = Lingo::config['language/dictionary']
		rescue
			raise "Fehler in der .lang-Datei bei 'language/dictionary'"
		end if @@library_config.nil?
		
		#		Informationen f�r Teilnehmer vorbereiten
		@config = config
		@subscriber = Array.new
		
		#		Teilnehmer initialisieren
		init if self.class.method_defined?(:init)
		
		@attendee_can_control = self.class.method_defined?(:control)
		@attendee_can_process = self.class.method_defined?(:process)
		
		@skip_this_command = false
	end


public

	def add_subscriber( subscriber )
		@subscriber += subscriber
	end



	def listen(obj)
	  
		unless obj.is_a?(AgendaItem)
			#		Informationen zum aktuellen Tagesordnungspunkt (TOP) verarbeiten
			if @attendee_can_process
				inc('Objekte empfangen')
				process(obj) 
			else
				forward(obj)
			end
		else
			#		Neuen TOP verarbeiten
			if @attendee_can_control
				inc('TOPs empfangen')
				control(obj.cmd, obj.param) 
			end

			#		Spezialbehandlung f�r einige TOPs nach Verarbeitung
			case obj.cmd
			#		keine weitere Behandlung oder Weiterleitung
			when STR_CMD_TALK then nil
			#		Standardprotokollinformationen ausgeben
			when STR_CMD_STATUS
				printf "\nTeilnehmer <%s> verbunden von '%s' nach '%s' berichtet...\n", @config['name'], @config['in'], @config['out']					
				report.to_a.sort.each { |info| puts "   #{info[0]} = #{info[1]}" }
				forward(obj.cmd, obj.param)
			else
				if @skip_this_command
					@skip_this_command = false
				else
					forward(obj.cmd, obj.param)
				end
			end
		end
	end


	def talk(obj)
		@subscriber.each { |attendee| attendee.listen(obj) }
	end


private
	
	def deleteCmd
		@skip_this_command = true
	end
	

	def forward(obj, param=nil)
		if param.nil?
			#		Information weiterreichen
			talk(obj)
		else
			#		TOP weiterreichen (wenn keine Warnung oder Fehler)
			case obj
				when STR_CMD_WARN	then printf "+%s\n|   %s: %s\n+%s\n", '-'*60, @config['name'], param, '-'*60
				when STR_CMD_ERR	then printf "%s\n=   %s: %s\n%s\n", '='*61, @config['name'], param, '='*61;	exit( 1 )
				else
					talk(AgendaItem.new(obj, param))
			end
		end
	end


	#	---------------------------------------------------
	#		Konfigurationshilfsmethoden
	#	---------------------------------------------------
	def has_key?(key)
		!@config.nil? && @config.has_key?(key)
	end

	
	def get_key(key, default=nil)
		forward(STR_CMD_ERR, "Attribut #{key} nicht gesetzt") if default.nil? && !has_key?(key)
		@config.fetch(key, default)
	end


	def get_array(key, default=nil)
		get_key(key, default).split(STRING_SEPERATOR_PATTERN)
	end
	

	#	---------------------------------------------------
	#		Abstrakte Methoden
	#
	#		init
	#		control(cmd, param)
	#		process(obj)
	#	---------------------------------------------------
end


#==============================================================================
#		BufferedAttendee 
#==============================================================================

class BufferInsert
	attr_reader :position, :object

private

	def initialize(pos, obj)
		@position = pos
		@object = obj
	end

end



class BufferedAttendee < Attendee

private

	def initialize(config)
		#	In den Buffer werden alle Objekte geschrieben, bis process_buffer? == true ist
		@buffer = []
		#	deferred_inserts beeinflussen nicht die Buffer-Gr��e, sondern werden an einer 
		#	bestimmten Stelle in den Datenstrom eingef�gt
		@deferred_inserts = []
		super
	end

protected
	
	def process(obj)
		@buffer.push(obj)
		if process_buffer?
			process_buffer
		end
	end

private
	
	def forward_buffer
		#	Aufgeschobene Einf�gungen in Buffer kopieren
		@deferred_inserts.sort! { |x,y| y.position <=> x.position }
		@deferred_inserts.each do |ins|
			case ins.position
			when 0				then	@buffer.unshift(ins.object)
			when @buffer.size-1	then	@buffer.push(ins.object)
			else
				@buffer = @buffer[0...ins.position] + [ins.object] + @buffer[ins.position..-1]
			end
		end
		@deferred_inserts.clear

		#	Buffer weiterleiten
		@buffer.each do |obj|
			forward(obj)
		end
		@buffer.clear
	end

	
	def process_buffer?
		true
	end
	

	def process_buffer
		#	to be defined by child class
	end


	def deferred_insert(pos, obj)
		@deferred_inserts << BufferInsert.new(pos, obj)
	end	
	
end

