#!/usr/bin/env ruby
require 'optparse'
require 'logger'
require 'roo'
require 'csv'
require 'write_xlsx'




$logger = Logger.new(STDOUT)
VERSION = "v.0.0.1"

original_formatter = Logger::Formatter.new

$logger.formatter = Proc.new do |severity,time,progname,msg|
  message = original_formatter.call(severity, time, progname, msg)
  if severity == "ERROR"
    STDERR.puts message
  end
  message
end

# Initialize logger
def setup_logger(loglevel)
  case loglevel
  when "debug"
    $logger.level = Logger::DEBUG
  when "warn"
    $logger.level = Logger::WARN
  when "info"
    $logger.level = Logger::INFO
  else
    $logger.level = Logger::ERROR
  end
end

def setup_options(args)
  options = {:n =>  75}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] in.xlsx go_terms.txt out.xlsx"
    opts.separator ""
    opts.separator "Read xlxs file, and add genes from go terms"

    opts.separator ""
    #opts.on("-n", "--number [NUMBER]",
    #  :REQUIRED,Integer,
    #  "How many bases to trim?, Default: 75 bases") do |n|
    #  options[:n] = n
    #end

    opts.on("-v", "--verbose", "Run verbosely") do |v|
      options[:log_level] = "info"
    end

    opts.on("-V","--version", "Print version") do |v|
      STDOUT.puts VERSION
      exit()
    end

    opts.on("-d", "--debug", "Run in debug mode") do |v|
      options[:log_level] = "debug"
    end

  end

  args = ["-h"] if args.length == 0
  opt_parser.parse!(args)
  raise "Please specify the input files!" if args.length != 3
  options
end

def read_go_terms(go_terms)
  genes=[]
  CSV.foreach(go_terms, {:headers => :first_row, :col_sep => "\t"}) do |row|
    genes << row["Symbol"]

    genes << row["Aliases"].split(/[\ ,]/).keep_if {|e| !e.empty?} if row["Aliases"]
  end
  genes.flatten!
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)
  in_xlsx = argv[0]
  go_terms = argv[1]
  out_xlsx = argv[2]
  genes = read_go_terms(go_terms)
  # Create a new Excel workbook
  out_workbook = WriteXLSX.new(out_xlsx)

  # Add a worksheet
  worksheet = out_workbook.add_worksheet
  workbook = Roo::Excelx.new(in_xlsx)
  workbook.default_sheet = workbook.sheets[0]
  headers = []
  workbook.row(1).each_with_index {|header,i| headers << i; worksheet.write(0,i,header)}
  #for i in 0..headers.length
  #  worksheet.write(0,i,headers[i])
  #end
  ((workbook.first_row + 2)..workbook.last_row).each do |row|
    gene_name = workbook.row(row)[headers[1]]
    for i in 0..headers.length
      puts "Row: #{row}, Column: #{i}"
      if workbook.row(row)[i]
        worksheet.write(row-1,i,workbook.row(row)[i])
      end
    end
    if genes.include?(gene_name)
      worksheet.write(row-1,headers.length,"YES")
    end
  end
  out_workbook.close

end

if __FILE__ == $0
  run(ARGV)
end
