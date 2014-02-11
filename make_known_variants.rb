#!/usr/bin/env ruby
require 'optparse'
require 'logger'

# 2014/2/11 Katharina Hayer

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
  options = {:cut_off =>  100.0, :log_level => "info", :pre_fix => "syrian_"}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] in.vcf out.vcf"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""

    opts.on("-c", "--cut_off [CUT_OFF]",
      :REQUIRED, Float,
      "QUAL cut off? DEFAULT: 500.0") do |a|
      options[:cut_off] = a
    end

    opts.on("-p", "--pre_fix [PRE_FIX]",
      :REQUIRED,String,
      "Prefix for SNP. DEFAULT: syrian_") do |pre_fix|
      options[:pre_fix] = pre_fix
    end

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
  out_vcf = File.open(ARGV[1],'w')

  counter = 0
  in_vcf.each do |line|
    line.chomp!
    if line =~ /^##/
      out_vcf.puts line
    else
      chrom, pos, id, ref, alt, qual, filter, info, format, syrian = line.split("\t")
      if line =~ /^#/
        out_vcf.puts line.split("\t")[0..-3].join("\t")
      else
        if qual.to_f >= options[:cut_off]
          id = "#{options[:pre_fix]}#{counter}"
          counter += 1
          out_vcf.puts "#{chrom}\t#{pos}\t#{id}\t#{ref}\t#{alt}\t.\t.\t#{info}"
        end
      end
    end
  end
  out_vcf.close
  in_vcf.close
end

if __FILE__ == $0
  run(ARGV)
end