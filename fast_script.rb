#!/usr/bin/env ruby

usage =<<EOF

  #{$0} input.vcf sample_number control_number [stdout]
 -----------------------------------------


  format out:

  location  start end #_of_homozygot_snps
  ...
  chr1  0 500000 50
  chr1  1 500001 50
  chr1  2 500002 51
  ...
EOF

if ARGV.length != 3
  puts usage
  exit
end


file = ARGV[0]
sample_number = ARGV[1].to_i + 8
control_number = ARGV[2].to_i + 8

File.open(file).each do |line|
  next if line =~ /^#/
  line = line.split("\t")
  info = line[sample_number].split(":")

  next if  !(info[0] =~ /1\/1/) && !(info[0] =~ /0\/1/) && !(info[0] =~ /0\/2/) && !(info[0] =~ /2\/2/)
  next if info[2].to_i < 10
  next if info[3].to_f < 30.0

  # Compare it to control

  info_control = line[control_number].split(":")

  next if info_control[0] =~ /1\/1/ && !(info[0] =~ /2\/2/) && info[3].to_f >= 20.0
  next if info_control[0] == info[0] &&  info[3].to_f >= 20.0



  allele_frequency = info[1].split(",")
  num_reference = allele_frequency.delete_at(0).to_f
  num_mut_reads = allele_frequency.max.to_f
  #next if num_reference > num_mut_reads
  num_all_reads = info[2].to_f
  num_mut_reads = num_all_reads if num_all_reads < num_mut_reads
  frequency = num_mut_reads / num_all_reads
  puts "#{line[0]}\t#{line[1]}\t#{frequency}"
  #puts info.join(":")
  #puts info_control.join(":")
  #exit if frequency < 0.1


end
