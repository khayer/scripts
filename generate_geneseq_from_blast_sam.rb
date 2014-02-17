#!/usr/bin/env ruby
require 'optparse'
require 'logger'

# 2014/2/14 Katharina Hayer

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
    opts.banner = "Usage: #{$0} [options] blast samfile outfile.fa"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""
    opts.separator "Sam file must be sorted!"

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

def read_blast(blast)
  gene_ranges = Hash.new
  current_query = ""
  last_tname = ""
  tstarts = []
  tends = []
  File.open(blast).each do |line|
    line.chomp!
    qname,tname,identities,length,mismat,gaps,qstar,tqend,tstart,tend,eval,score =
    line.split("\t")

    if (qname != current_query || tname != last_tname) && !tstarts.empty?
      gene_ranges[last_tname] = [] unless gene_ranges[last_tname]
      start = tstarts.min- 50000
      stop = tends.max + 50000
      gene_ranges[last_tname] << [start,stop,current_query]
      tstarts = []
      tends = []
    end

    current_query = qname
    last_tname = tname
    tstarts << tstart.to_i
    tends << tend.to_i

  end
   gene_ranges[last_tname] = [] unless gene_ranges[last_tname]
   gene_ranges[last_tname] << [tstarts.min,tends.max,current_query]

  gene_ranges.each_pair do |contig, ranges|
    gene_ranges[contig] = ranges.sort
  end

  gene_ranges
end

def process_reads(reads, current_range,contigs,outfile_handle)
  fwd_tmp = File.open("fwd_tmp.fa", "w")
  rev_tmp = File.open("rev_tmp.fa", "w")
  reads.each_pair do |reads_name,sequences|
    if sequences[0] != "" && sequences[1] != ""
      fwd_tmp.puts ">#{reads_name}"
      fwd_tmp.puts sequences[0]
      rev_tmp.puts ">#{reads_name}"
      rev_tmp.puts sequences[1]
    end
  end
  fwd_tmp.close
  rev_tmp.close

  out_trinity = run_trinity("fwd_tmp.fa","rev_tmp.fa")

  File.open(out_trinity).each do |line|
    line.chomp!
    line = "line#{current_range[-1]}" if line =~ \^>\
    outfile_handle.puts line
  end
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  blast = ARGV[0]
  sam_file = ARGV[1]
  outfile = File.open(ARGV[2],'w')

  outfile_handle = File.open(outfile,'w')

  gene_ranges = read_blast(blast)
  contigs = Hash.new
  reads = Hash.new
  current_range = nil

  File.open(sam_file).each do |line|
    line.chomp!
    if line =~ /^@SQ/
      name = line.split("SN:")[1].split(" ")[0]
      length = line.split("LN:")[1].split(" ")[0].to_i
      contigs[name] = length
    end
    unless line =~ /^@/
      # FCH8JMRADXX:2:1214:6191:40267#CGCTCATT  1123  gi|472278466|gb|KB708127.1| 58193489  60  100M  = 58193525  136 CATAAGTATTAATCTATGTATTTCCACGTGGAGAATGCTTCAGTGTCCTATATTCCCAACCACTACATGGCATCTTCTCTGGTGGCTTCTCTTTGCCTTC  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      name, bit_flag, tname, tstart, qual, cigar, d,d,d,seq = line.split("\t")

      current_range = gene_ranges[tname][0] unless current_range
      next if tstart.to_i < current_range[0]
      if tstart.to_i < current_range[1]

        bit_flag = bit_flag.to_i.to_s(2).split("")
        reads[name] = ["",""] unless reads[name]
        if bit_flag[-6] == "1"
           reads[name][0] = seq
        elsif bit_flag[-7] == "1"
          reads[name][1] = seq
        else
          raise("READ NOT FIRST OR LAST IN PAIR?")
        end

      else
        process_reads(reads, current_range,contigs,outfile_handle)
        current_range =  gene_ranges[tname][0]
        reads = Hash.new
      end
    end

    outfile_handle.close


end

if __FILE__ == $0
  run(ARGV)
end