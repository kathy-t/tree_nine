version 1.0

task usher_sampled_diff {
	input {
		Boolean detailed_clades = false
		File diff
		File i
		Int optimization_radius = 0
		Int max_parsimony_per_sample = 1000000
		Int max_uncertainty_per_sample = 1000000
		String outfile_usher
		File ref

		# WDL specific -- note that cpu does not directly set usher's
		# threads argument, but it does affect the number of cores
		# available for use (by default usher uses all available)
		Int cpu = 4
		Int memory = 8
		Int preempt = 1
	}

	Int disk_size = ceil(size(diff, "GB")) + ceil(size(ref, "GB")) +  ceil(size(i, "GB"))
	String detailed_clades_arg = if !(detailed_clades) then "" else "-D "

	command <<<
		matUtils summary -i ~{ref}
		usher-sampled ~{detailed_clades_arg}--optimization_radius=~{optimization_radius} \
			-e ~{max_uncertainty_per_sample} \
			-E ~{max_parsimony_per_sample} \
			--diff "~{diff}" \
			-i "~{i}" \
			--ref "~{ref}" \
			-o "~{outfile_usher}.pb"
		ls
	>>>

	runtime {
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		docker: "quay.io/biocontainers/usher:0.6.1--h99b1ad8_1"
		memory: memory + " GB"
		preemptible: preempt
	}

	output {
		File usher_tree = outfile_usher + ".pb"
		File? clades = "clades.txt" # only if detailed_clades = true
	}
}

task convert_to_taxonium {
	input {
		String outfile_taxonium
		File usher_tree
	}

	Int disk_size = ceil(size(usher_tree, "GB"))

	command <<<
		usher_to_taxonium -i "~{usher_tree}" -o "~{outfile_taxonium}.jsonl.gz"
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "ashedpotatoes/sranwrp:1.1.4"
		memory: "8 GB"
		preemptible: 1
	}

	output {
		File taxonium_tree = outfile_taxonium + ".jsonl.gz"
	}
}

workflow usher_sampled_diff_to_taxonium {
	input {
		File diff
		File i
		String outfile_usher = "newref"
		String outfile_taxonium = "newref"
		File ref
	}

	call usher_sampled_diff {
		input:
			diff = diff,
			i = i,
			outfile_usher = outfile_usher,
			ref = ref
	}

	call convert_to_taxonium {
		input:
			outfile_taxonium = outfile_taxonium,
			usher_tree = usher_sampled_diff.usher_tree
	}
}