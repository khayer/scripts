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
    opts.banner = "Usage: #{$0} [options] blast samfile outfile.fa path_to_trinity"
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

def run_trinity(fwd,rev,path_to_trinity)
  #~/Tools/trinityrnaseq_r2012-10-05/Trinity.pl --CPU 8 --seqType fa --JM 110G --output trinity/ --left fwd.fa --right rev.fa
  cmd = "#{path_to_trinity}/Trinity.pl --seqType fa --JM 10G --output trinity/ --left #{fwd} --right #{rev}"
  $logger.info(cmd)
  k = `#{cmd}`
  # util/alignReads.pl --left fwd.fa --right rev.fa --seqType fa --target trinity/Trinity.fasta --aligner bowtie
  #cmd = "#{path_to_trinity}/util/alignReads.pl --left #{fwd} --right #{rev} --seqType fa --target trinity/Trinity.fasta --aligner bowtie"
  #$logger.info(cmd)
  #k = `#{cmd}`
  # util/RSEM_util/run_RSEM.pl --transcript trinity/Trinity.fasta --name_sorted_bam bowtie_out/bowtie_out.nameSorted.PropMapPairsForRSEM.bam --paired
  cmd = "#{path_to_trinity}/util/RSEM_util/run_RSEM_align_n_estimate.pl  --transcripts trinity/Trinity.fasta --seqType fa  --left #{fwd} --right #{rev} -- --no-bam-output"
  $logger.info(cmd)
  k = `#{cmd}`
  cmd = "grep -w \"100.00\" RSEM.isoforms.results | cut -f 1 | xargs samtools faidx trinity/Trinity.fasta > high_quality.fasta"
  $logger.info(cmd)
  k = `#{cmd}`
  `rm -r RSEM* trinity rev_tmp.fa fwd_tmp.fa`
  "high_quality.fasta"
end

def process_reads(reads, current_range,contigs,outfile_handle,path_to_trinity)
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

  out_trinity = run_trinity("fwd_tmp.fa","rev_tmp.fa",path_to_trinity)

  File.open(out_trinity).each do |line|
    line.chomp!
    line = "#{line}#{current_range[-1]}" if line =~ /^>/
    outfile_handle.puts line
  end
  `rm high_quality.fasta`
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  blast = ARGV[0]
  sam_file = ARGV[1]
  outfile_handle = File.open(ARGV[2],'w')
  path_to_trinity = ARGV[3]

  gene_ranges = read_blast(blast)
  contigs = Hash.new
  reads = Hash.new
  i = 0
  current_range = nil
  last_tname = ""
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
      next unless gene_ranges.keys.include?(tname)
      if tname != last_tname

        last_tname = tname
        unless reads.empty?
          $logger.info("current range: #{current_range}")
          $logger.info("reads length: #{reads.length}")
          process_reads(reads, current_range,contigs,outfile_handle,path_to_trinity)
        end
        current_range = gene_ranges[tname][0]
        i = 0
        $logger.info("current range: #{current_range}")
        $logger.info("reads length: #{reads.length}")
        reads = Hash.new


      end
      current_range = gene_ranges[tname][0] unless current_range

      next if tstart.to_i < current_range[0]
      if tstart.to_i < current_range[1]

        bit_flag = bit_flag.to_i.to_s(2).split("")
        reads[name] = ["",""] unless reads[name]
        if bit_flag[-7] == "1"
           reads[name][0] = seq
        elsif bit_flag[-8] == "1"
          reads[name][1] = seq
        else
          $logger.error(line)
          raise("READ NOT FIRST OR LAST IN PAIR?")
        end

      else
        if reads != {}
          $logger.info("PROCESS:: current range: #{current_range}")
          $logger.info("PROCESS:: reads length: #{reads.length}")
          process_reads(reads, current_range,contigs,outfile_handle,path_to_trinity)
        end
        i += 1

        current_range =  gene_ranges[tname][i]
        $logger.info("current range: #{current_range}; i = #{i}") if current_query
        $logger.info("reads length: #{reads.length}") if current_query
        reads = Hash.new
      end
    end
  end
  outfile_handle.close
end

if __FILE__ == $0
  run(ARGV)
end