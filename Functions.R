#use this function to check if each package installed
#if a package is installed, it will be loaded
#if any are not, the missing package(s) will be installed and loaded

package.check <- function(packages){
  lapply(packages, FUN = function(x) {
  if (!require(x, character.only = TRUE)) {
    install.packages(x, dependencies = TRUE)
    library(x, character.only = TRUE)
  }
})
}
