# Perl-Randomize-Firered

## How to install

Change current directory to the Pokémon Firered decompilation

Execute:

```shell
git clone https://github.com/sergiotarxz/Perl-Randomize-Firered.git
cpan -T JSON
```


## How to generate a build

You should have all the prerequisites to compile pokefirered and do the following

```shell
git stash && perl ./Perl-Randomize-Firered/randomize.pl && make
```

The resulting build will be in `pokefirered.gba`.
