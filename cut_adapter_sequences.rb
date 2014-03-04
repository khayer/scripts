#!/usr/bin/env ruby
require 'optparse'
require 'logger'
require 'csv'

# 2014/2/27 Katharina Hayer

$logger = Logger.new(STDERR)


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
  options = {:cut_off =>  5, :log_level => "info"}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] genes_file blastx_master compare1 [compare2...]"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""

    opts.on("-c", "--cut_off [CUT_OFF]",
      :REQUIRED, Float,
      "Number of reads cut off? DEFAULT: 5") do |a|
      options[:cut_off] = a
    end

    #opts.on("-p", "--pre_fix [PRE_FIX]",
    #  :REQUIRED,String,
    #  "Prefix for SNP. DEFAULT: syrian_") do |pre_fix|
    #  options[:pre_fix] = pre_fix
    #end

    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options[:log_level] = "info"
    end

    opts.on("-d", "--debug", "Run in debug mode") do |v|
      options[:log_level] = "debug"
    end
  end

  args = ["-h"] if args.length == 0
  opt_parser.parse!(args)
  raise "Please specify the sam files" if args.length == 0
  options
end

def read_adapter(adapter_file)
  adapters = {}
  range = (0..99)
  CSV.foreach(adapter_file, {:headers => :first_row, :col_sep => " "} do |row|
    new_range = range.to_a - (row["reads_start"].to_i..row["reads_end"].to_i).to_a
    new_range = (new_range[0]..new_range[-1])
    while !(new_range.each_cons(2).all? { |x,y| y == x + 1 })
      if row["reads_start"].to_i < 99-row["reads_end"].to_i
        new_range.delete_at(0)
      else
        new_range.delete_at(-1)
      end
    end
    adapters[row["#reads_id"]] = new_range
  end
  adapters
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  # genes_file blastx_master compare1 [compare2...]
  fwd = ARGV[0]
  rev = ARGV[1]
  fwd_adapter = ARGV[2]
  rev_adapter = ARGV[3]

  fwd_out = File.open("#{fwd}_new.fq",'w')
  rev_out = File.open("#{rev}_new.fq",'w')

  fwd_adapters = read_adapter(fwd_adapter)
  rev_adapters = read_adapter(rev_adapter)

  rev_hand = File.open(rev)
  i = 0
  range_fwd = (0..99)
  range_rev = (0..99)
  File.open(fwd).each do |line|
    line.chomp!
    line_rev = rev_hand.readline().chomp
    case i
    when 0
      name = line[1..-1]
      range_fwd = fwd_adapters[name] if fwd_adapters[name]
      name_rev = line_rev[1..-1]
      range_rev = rev_adapters[name] if rev_adapters[name]
      i += 1
    when 1
      line = line[range_fwd]
      line_rev = line_rev[range_rev]
      i += 1
    when 2
      i += 1
    when 3
      line = line[range_fwd]
      line_rev = line_rev[range_rev]
      i = 0
    end
    fwd_out.puts line
    rev_out.puts line
  end
  rev_hand.close
  fwd_out.close
  rev_out.close

end

if __FILE__ == $0
  run(ARGV)
end