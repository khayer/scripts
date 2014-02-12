#!/usr/bin/env ruby
require 'optparse'
require 'logger'

# 2014/2/12 Katharina Hayer

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
    opts.banner = "Usage: #{$0} [options] in.vcf sample_name"
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

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  in_vcf = File.open(ARGV[0])
  sample_name = ARGV[1]

  contigs = Hash.new
  sample_number = nil
  count = 0
  total_number_of_bases = 0

  in_vcf.each do |line|
    line.chomp!
    if line =~ /^##/
      if line =~ /^##contig=/
        # ##contig=<ID=gi|472278118|gb|KB708475.1|,length=199378>
        length = line.split("length=")[1].to_i
        contig_name = line.split("ID=")[1].split(",")[0]
        contigs[contig_name] = length
        total_number_of_bases += length
      end
    else
      if line =~ /^#/
        fields = line.split("\t")
        raise "Sample Name #{sample_name} not in header" unless fields.include?(sample_name)
        sample_number = fields.index(sample_name)
      else
        fields = line.split("\t")
        # 0/1:8,9:17:99:218,0,184
        next if fields[sample_number] =~ /\.\/\./
        sample_info = fields[sample_number].split(":")
        next if sample_info[2].to_i < options[:cut_off]
        next unless sample_info[0] =~ /1\/1/
        count += 1
      end
    end
  end
  puts "SNP frequency #{count} SNP's per #{total_number_of_bases} number of bases"
  puts "SNP frequency #{count/total_number_of_bases*100000} per 100,000 bases"
end

if __FILE__ == $0
  run(ARGV)
end