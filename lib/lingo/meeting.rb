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
#  welcomeATlex-lingoDOTde near 50°55'N+6°55'E.
#
#  Lex Lingo rules from here on

require 'lingo/const'
require 'lingo/attendees'

require 'lingo/attendee/abbreviator'
require 'lingo/attendee/debugger'
require 'lingo/attendee/decomposer'
require 'lingo/attendee/dehyphenizer'
require 'lingo/attendee/multiworder'
require 'lingo/attendee/noneword_filter'
require 'lingo/attendee/objectfilter'
require 'lingo/attendee/variator'
require 'lingo/attendee/sequencer'
require 'lingo/attendee/synonymer'
require 'lingo/attendee/textreader'
require 'lingo/attendee/textwriter'
require 'lingo/attendee/tokenizer'
require 'lingo/attendee/vector_filter'
require 'lingo/attendee/wordsearcher'
require 'lingo/attendee/helper'

class Lingo

  class Meeting

    include Const

    #  Meeting initialisieren
    def initialize
      @attendees = Array.new
    end

    #  Einladen aller Teilnehmer
    def invite( invitation_list )
      #  Daten für Verlinkung der Teilnehmer vorbereiten
      supplier   = Hash.new( [] )
      subscriber = Hash.new( [] )

      # Daten für automatische Verlinkung vorbereiten
      last_link_out = ''
      auto_link_number = 0

      #  Teilnehmer einzeln einladen
      invitation_list.each do |cfg|
        #  att = {'attendee' => {'name'=>'Attendee', 'in'=>'nase', 'out'=>'ohr', 'param'=>'hase'}}
        config = cfg.values[ 0 ]
        config['name'] = cfg.keys[ 0 ].capitalize

        #  Link-Parameter standardisieren
        [ 'in', 'out' ].each do |key|
          config[ key ] ||= ''
          config[ key ].downcase!
        end

        # Automatisch verlinken
        if config['in'] == ''
          config['in'] = last_link_out
        end
        if config['out'] == ''
          config['out'] = 'auto_link_out_' + (auto_link_number += 1).to_s
        end
        last_link_out = config['out']

        #  Attendee-Daten ergänzen
        data = Lingo.config["language/attendees/#{config['name'].downcase}"]
        config.update( data ) unless data.nil?

        #  Teilnehmer-Objekt erzeugen
        attendee = Lingo::Attendee.const_get(config['name']).new(config)
        exit if attendee.nil?
        @attendees << attendee

        #  Supplier und Subscriber merken
        config[ 'in' ].split( STRING_SEPERATOR_PATTERN ).each do |interest|
          subscriber[ interest ] += [ attendee ]
        end
        config[ 'out' ].split( STRING_SEPERATOR_PATTERN ).each do |theme|
          supplier[ theme ] += [ attendee ]
        end
      end

      #  Teilnehmer verlinken
      supplier.each do |supp|
        channel, attendees = supp
        attendees.each do |att|
          att.add_subscriber( subscriber[ channel ] )
        end
      end
    end

    # => protocol = 0   keep quiet, i.e. for testing
    # => protocol = 1   report status
    # => protocol = 2   report performance
    # => protocol = 3   report status and performance
    def start( protocol )
      #  prepare meeting
      @attendees.first.listen(AgendaItem.new(STR_CMD_REPORT_STATUS)) if (protocol & 1) != 0
      @attendees.first.listen(AgendaItem.new(STR_CMD_REPORT_TIME))   if (protocol & 2) != 0

      #  hold meeting
      start_time = Time.new
      @attendees.first.listen(AgendaItem.new(STR_CMD_TALK))
      end_time = Time.new

      #  end meeting, create protocol
      if (protocol & 3) != 0
        puts "Require protocol..."
        puts '-'*61
        @attendees.first.listen(AgendaItem.new(STR_CMD_STATUS))

        #  duration of meeting
        duration, unit = (end_time-start_time), 'second'
        duration, unit = (duration/60.0), 'minute' if duration > 60
        duration, unit = (duration/60.0), 'hour'   if duration > 60
        unit += 's' if duration > 1

        printf "%s\nThe duration of the meeting was %5.2f %s\n", '-'*61, duration, unit
      end
    end

    def reset
      @attendees = Array.new
    end

  end

end
