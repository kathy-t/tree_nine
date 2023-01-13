version 1.0

task usher_sampled {
	input {
		File diff
		File i
		String o
		File ref
	}

	Int disk_size = ceil(size(diff, "GB")) + ceil(size(ref, "GB")) +  ceil(size(i, "GB"))

	command <<<
		usher-sampled --optimization_radius=0 \
			--diff ~{diff} \
			-i ~{i} \
			--ref ~{ref} \
			-o ~{o}
		ls
	>>>

	runtime {
		cpu: 4
		disks: "local-disk " + disk_size + " SSD"
		docker: "quay.io/biocontainers/usher:0.6.1--h99b1ad8_1"
		memory: "8 GB"
		preemptible: 1
	}
}

workflow usher_sampled_wf {
	input {
		File diff
		File i
		String o = "newref.pb"
		File ref
	}

	call usher_sampled {
		input:
			diff = diff,
			i = i,
			o = o,
			ref = ref
	}
}