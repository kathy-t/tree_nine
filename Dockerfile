FROM yecheng/usher@sha256:2b8fa3a0c1df6844bb7dd042c9861bc6110df83b340f5b925680bdae03aee3d0

# add the TB reference used by clockwork-plus and others (not committed to this repo since it's a bit big)
# see gs://topmed_workflow_testing/tb/ref, md5sum should be fca996be5de559f5f9f789c715f1098b
RUN mkdir ref
COPY ./Ref.H37Rv.tar ./ref/
RUN cd ./ref/ && tar -xvf Ref.H37Rv.tar

# add the known lineage SRA tree
RUN mkdir example_tree
COPY ./tb_alldiffs_mask2ref.L.fixed.pb ./example_tree/