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
  total_number_of_bases = 0
  compare_samples = Hash.new
  
  table = Hash.new
  ## table
  ## table[sample_name1] 

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
        avail_sample_numbers = (9...fields.length).to_a
        sample_number = fields.index(sample_name)
        table[sample_name] = 0
        avail_sample_numbers.delete(sample_number)
        all_names = []
        avail_sample_numbers.each do |num|
          compare_samples[fields[num]] = num
          table[fields[num]] = 0
          all_names << fields[num]
        end
        table[all_names.join("")] = 0
      else
        fields = line.split("\t")
        # 0/1:8,9:17:99:218,0,184
        next if fields[sample_number] =~ /\.\/\./
        sample_info = fields[sample_number].split(":")
        next if sample_info[2].to_i < options[:cut_off]
        next unless sample_info[0] =~ /1\/1/
        unique = true
        shared_with = []
        compare_samples.each_pair do |name,num|
          sam_info = fields[num].split(":")
          next if sam_info[2].to_i < options[:cut_off]
          next unless sam_info[0] =~ /1\/1/
          unique = false
          shared_with << name
        end
        if unique
          table[sample_name] += 1
        else
          table[shared_with.join("")] += 1
        end
      end
    end
  end
  puts table
end

if __FILE__ == $0
  run(ARGV)
end