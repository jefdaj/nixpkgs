{ kde, kdelibs, libkdegames }:
kde {
  buildInputs = [ kdelibs libkdegames ];
  meta = {
    description = "A single player arcade game. The player is invading various cities in a plane that is decreasing in height";
  };
}
