#!/usr/bin/env ruby
require 'optparse'
require 'logger'
require 'benchmarking_scripts'

# 2014/2/14 Katharina Hayer

$logger = Logger.new(STDERR)

class File
  def self.buffer(path)
    n = 0
    size = File.size( path )
    chunk = 2**16
    File.open(path, "rb") do |f|
      while n < size
        n += chunk
        yield f.sysread( chunk )
      end
    end
  end
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
  options = {:cut_off =>  5, :log_level => "info"}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] sequences.fa genes.gtf variations.vcf outfile.fa sample_name"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""
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

def read_sequences(sequences_file)
  sequences = {}
  name = ""
  seq = ""
  $logger.debug("reading sequences")
  File.open(sequences_file).each do |line|
    line.chomp!
    if line =~ /^>/
      unless name == ""
        sequences[name] = seq
        seq = ""
      end
      name = line.split(" ")[0].delete(">")
    else
      seq += line
    end
  end
  $logger.debug("done reading sequences")
  sequences[name] = seq
  sequences
end


def read_sequences2(sequences_file)
  sequences_index = {}
  $logger.debug("reading sequences")
  file_handle = File.open(sequences_file)
  file_handle.each do |line|
      line.chomp!
      if line =~ /^>/
        name = line.split(" ")[0].gsub(/^>/,"")
        sequences_index[name] = file_handle.pos
      end
  end
  $logger.debug("done reading sequences")
  puts sequences_index
  sequences_index
end

def read_variants(vcf_file)
  vcf = []
  File.open(vcf_file).each do |line|
    line.chomp!
    #puts line
    fields = line.split("\t")
    #puts fields
    info = fields[7]
    effects = info.split("EFF=")[1].split(",")
    effects.each do |eff|
      #puts eff
      next unless eff =~ /HIGH/
      eff = eff.split("|")
      # eff[8] is transcript_id
      vcf << eff[8] unless vcf.include?(eff[8])
    end
  end
  vcf
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  # sequences.fa genes.gtf variations.vcf outfile.fa sample_name"
  sequences_file = ARGV[0]
  genes_file = ARGV[1]
  vcf_file = ARGV[2]
  outfile_handle = File.open(ARGV[3],'w')
  sample_name = ARGV[4]

  sequences_index = read_sequences2(sequences_file)
  $logger.debug("reading gtf files; #{sequences_index.length} Transcripts!")
  genes = GTF.new(genes_file)
  genes.create_index()
  #puts genes.index
  $logger.debug("#{genes.index.length} Genes ")
  $logger.debug("reading vcf files")
  vcf = read_variants(vcf_file)
  $logger.debug("#{vcf.length} locations in gtf file (vcf[0] :#{vcf[0]}")

  fa_file = File.open(sequences_file)
  vcf.each do |transcript_id|
    $logger.debug("lopping through output")
    puts transcript_id
    key = genes.index.select {|e| e[-1].gsub(/\W/,"") == transcript_id}
    key = key.keys[0]
    puts key
    trans = genes.transcript(key)
    seq_contig = ""
    #fa_file.pos = sequences_index[key[0]]
    #fa_file.each do |line|
    #  line.chomp!
    #  break if line =~ /^>/
    #  seq_contig += line
    #end
    seq = ""
    for i in (0...trans.length/2)
      length = trans[i+1]-trans[i]
      offset = sequences_index[key[0]]+trans[i]
      seq += IO.read(sequences_file,length,offset).chomp!
    end
    outfile_handle.puts ">#{transcript_id}"
    outfile_handle.puts seq
  end


  outfile_handle.close
end

if __FILE__ == $0
  run(ARGV)
end