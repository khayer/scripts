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
    opts.banner = "Usage: #{$0} [options] sorted_blast sequences.fa genes_file outfile.fa sample_name"
    #opts.banner = "Usage: compare_fpkm_values [options] fpkm_values.txt"
    opts.separator ""
    opts.separator "genes_file example:"
    opts.separator "Bhlhe40 gi|146134431|ref|NM_011498.4|"
    opts.separator "Per2  gi|153792235|ref|NM_011066.3|"
    opts.separator ""
    opts.separator "prepare sorted_blast with:"
    opts.separator "awk '$12 > 120.0'  tblastx.out | sort -k 2,2 -k 12,12nr > tblastx_sorted.out"

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

def read_blast(blast,genes)
  rel_seq = {}
  genes.each_pair do |name,id|
    blast_id = `grep "#{id}" #{blast}`
    blast_id.chomp!
    lines = blast_id.split("\n").map {|e| e.split("\t")}
    id = nil
    fasta_name = nil
    lines.each do |line|
      name = line[0]
      if name.include?(line[1])
        fasta_name = name
        id = line[1]
        rel_seq[name] = id
        break
      end
    end
  end
  rel_seq
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
  #cmd = "#{path_to_trinity}/util/RSEM_util/run_RSEM_align_n_estimate.pl  --transcripts trinity/Trinity.fasta --seqType fa  --left #{fwd} --right #{rev} -- --no-bam-output"
  #$logger.info(cmd)
  #k = `#{cmd}`
  #cmd = "grep -w \"100.00\" RSEM.isoforms.results | cut -f 1 | xargs samtools faidx trinity/Trinity.fasta > high_quality.fasta"
  #$logger.info(cmd)
  #k = `#{cmd}`
  `mv trinity/Trinity.fasta high_quality.fasta`
  `rm -r trinity rev_tmp.fa fwd_tmp.fa`
  "high_quality.fasta"
end

def process_reads(reads, current_range,contigs,outfile_handle,path_to_trinity)
  fwd_tmp = File.open("fwd_tmp.fa", "w")
  rev_tmp = File.open("rev_tmp.fa", "w")
  reads.each_pair do |reads_name,sequences|
    if sequences[0].length > 50 && sequences[1].length > 50
      fwd_tmp.puts ">#{reads_name}/1"
      fwd_tmp.puts sequences[0]
      rev_tmp.puts ">#{reads_name}/2"
      rev_tmp.puts sequences[1]
    end
  end
  fwd_tmp.close
  rev_tmp.close

  out_trinity = run_trinity("fwd_tmp.fa","rev_tmp.fa",path_to_trinity)

  if File.exist?(out_trinity)

    File.open(out_trinity).each do |line|
      line.chomp!
      fields = line.split(" ")
      line = "#{fields[0]}#{current_range.join(":")} #{fields[1..-1].join(" ")}" if line =~ /^>/
      outfile_handle.puts line
    end
    `rm high_quality.fasta`
  end
end

def cut_seq(seq,cigar)
  cigar_letters = cigar.split(/\d/).keep_if {|e| e != ""}
  cigar_numbers = cigar.split(/\D/).map {|e| e.to_i}
  new_seq = ""
  cigar_letters.each_with_index do |letter, i|
    next if letter == "N" || letter == "D"
    if letter == "M"
      new_seq = seq[0..cigar_numbers[i]]
    else
      seq = seq[0..cigar_numbers[i]]
    end
  end
  new_seq
end

def read_genes_file(genes_file)
  genes = {}
  File.open(genes_file).each do |line|
    line.chomp!
    name, id = line.split(" ")
    genes[name] = id
  end
  genes
end

def run(argv)
  options = setup_options(argv)
  setup_logger(options[:log_level])
  $logger.debug(options)
  $logger.debug(argv)

  # sorted_blast sequences.fa genes_file outfile.fa sample_name
  blast = ARGV[0]
  sequences = ARGV[1]
  genes_file = ARGV[2]
  outfile_handle = File.open(ARGV[3],'w')
  sample_name = ARGV[4]

  genes = read_genes_file(genes_file)
  rel_seq = read_blast(blast,genes)

  rel_seq.each_pair do |name, id|
    seq = `samtools faidx #{sequences} "#{name}"`
    seq.chomp!
    seq.sub!(/^>#{name}/,">#{id}_#{sample_name}")
    outfile.puts(seq)
  end

  outfile_handle.close
end

if __FILE__ == $0
  run(ARGV)
end