# Test if the given path ${1} is
# a real file on the file system
function is_file() {
  if [[ -f "${1}" ]]
  then
    return 0;
  else
    return 1;
  fi
}

# Separate each part of the given string ${2} by the given
# delimiter ${1} and return them in an array
# from https://memoire-grise-liberee.fr.eu.org/Bash/function/strings/explode
function explode() {
    local delimiter="$1" string="$2"
    local IFS="${delimiter}"; shift; read -a array <<< "${string}";

    if [[ "${array[@]}" ]]; then echo "${array[@]}"; else return 1; fi

    unset IFS delimiter string;
}