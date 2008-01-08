PACKAGE_NAME  = 'lingo'
LINGO_VERSION = '1.6.6'
PACKAGE_PATH  = 'pkg/' + PACKAGE_NAME + '-' + LINGO_VERSION

begin
  require 'hen'

  Hen.lay!(:verbose => false) {{
    :rubyforge => {
      :project => nil
    },

    :rdoc => {
      :title => 'Lex Lingo - Application Documentation'
    },

    :test => {
      :files => FileList['test/*_test.rb', 'test/attendee/*_test.rb']
    },

    :gem => {
      :name              => PACKAGE_NAME,
      :version           => LINGO_VERSION,
      :append_svnversion => false,
      :summary           => 'Lingo - Linguistic Lego',
      :files             => FileList['lib/**/*.rb', 'bin/*'].to_a,
      :extra_files       => FileList[
        '[A-Z]*', 'example/**/*', 'dict/**/*', 'config/*', 'info/*', 'test/**/*'
      ].to_a
    }
  }}
rescue LoadError
  warn "Please install the 'hen' gem for additional tasks."
end

require 'rake/clean'

# => CLEAN-FILES
# Diese Dateien werden mit dem Aufruf von 'rake clean' gelöscht
# (temporäre Dateien, die nicht dauerhaft benötigt werden)
CLEAN.include('example/*.{mul,non,seq,syn,ve?,csv}')
CLEAN.include('dict/*/{*.rev,test_auto_*}')
CLEAN.include('test/{test.*,text.non}')

# => CLOBBER-FILES
# Diese Dateien werden mit dem Aufruf von 'rake clobber' gelöscht
# (Dateien, die auch wieder neu generiert werden können)
CLOBBER.include('dict/*/store', 'doc' ,'pkg/*')
CLOBBER.exclude(PACKAGE_PATH + '.*')

#desc 'Default: proceed to testing lab...'
task :default => :test

desc 'Stelle die aktuelle Version auf Subversion bereit'
task :deploy => [:package, :test_remote] do
  system('svn status') || exit
end

desc 'Vollständiger Test der Lingo-Funktionalität'
task :test_all => [:test, :test_txt, :test_lir]

desc 'Vollständiges Testen der Lingo-Prozesse anhand einer Textdatei'
task :test_txt do
  # => Testlauf mit normaler Textdatei
  system('ruby bin/lingo -c test example/artikel.txt') || exit

  # => Für jede vorhandene _ref-Datei sollen die Ergebnisse verglichen werden
  Dir['test/ref/artikel.*'].inject(true) { |continue, ref|
    org = ref.sub(/test\/ref/, 'example')

    puts '#' * 60 + "  Teste #{org}"

    system("diff -b #{ref} #{org}")
  } || exit
end

desc 'Vollständiges Testen der Lingo-Prozesse anhand einer LIR-Datei'
task :test_lir do
  # => Testlauf mit LIR-Datei
  system('ruby bin/lingo -c lir example/lir.txt') || exit

  # => Für jede vorhandene _ref-Datei sollen die Ergebnisse verglichen werden
  Dir['test/ref/lir.*'].inject(true) { |continue, ref|
    org = ref.sub(/test\/ref/, 'example')

    puts '#' * 60 + "  Teste #{org}"

    continue = system("diff -b #{ref} #{org}")
  } || exit
end

desc 'Vollständiges Testen der fertig paketierten Lingo-Version'
task :test_remote => :package do
  chdir(PACKAGE_PATH) do
    # => Testlauf im Package-Verzeichnis
    system('rake test_all') || exit
  end
end

=begin

desc '...starting tests, stand-by...'
task :test => :test_init

TST_PATH = ???
GPL_TEXT = File.read('info/gpl-hdr.txt')
LEX_LINE = "#  Lex Lingo rules from here on"

def lingo_gpl
  message('Aktualisiere GPL-Hinweis')

  # GPL-Header aller Ruby-Dateien erneuern
  Dir[TST_PATH + '/**/*.rb'].each { |filename|
    content = File.read(filename)

    if content.sub!(/\A.*?^#{LEX_LINE}$\s*/m, GPL_TEXT)
      File.open(filename, 'w') { |file|
        file.puts content
      }
    end
  }
end

=end
