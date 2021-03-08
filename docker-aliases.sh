# helpful shortcuts for working with docker-compose and friends

alias dc='docker-compose'
dsh() {
  IMAGE=${1};
  FLAGS=${2};
  docker exec -it ${FLAGS} ${IMAGE} sh
}
