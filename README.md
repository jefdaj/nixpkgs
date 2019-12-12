nixpkgs
=======

This is my fork of [NixOS/nixpkgs](https://github.com/nixos/nixpkgs). I've
added a lot of software for personal use, and will eventually get around to
cleaning it up and sending pull requests upstream. In the meantime, let me know
if you're interested in anything here! Maybe you're the author, or you can't
get it to work, or you got it working better, or whatever.

Most of the packages are related to bioinformatics:

* Bioconductor packages for R (merged!)
* A hackish script that auto-updates all the R packages
* BioPython
* aliview
* ape, with dependencies sdx and tclkit
* argtable (what depends on this again?)
* clustal-omega
* dendroscope
* emboss (someone else did it too)
* fasttree
* fastx-toolkit (and the dependency libgtextutils)
* figtree
* gblocks
* igv (someone else did it too)
* igvtools
* kallisto
* ncbi-blast
* raxml
* seqtrace
* sunwait
* t-coffee
* tarql
* trimal
* viennarna
* xlsx2csv
* FEBA (TODO: package properly)
* bioperl (TODO: package each part in perl-packages.nix)
* diamond
* fastme
* gitit
* hmmer
* muscle
* psiblast-exb
* shortcut
* tnseq-transit

But there are also some random ones:

* docopts, which uses python to generate shell script CLI interfaces
* motion, a daemon for watching security cameras
* terminal-velocity a CLI note-taking program similar to Notational Velocity
* tidal, a Haskell library for live coding music (super fun!)
* tidal-vim
* shreddit, which overwrites reddit comments before deleting them
  (may not be useful as of 2016 because new privacy policy allows versioning)
* mypaint
* etmtk, a task manager
* Bitcoin XT and Unlimited
