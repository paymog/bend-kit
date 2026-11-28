import { Container, getContainer } from "@cloudflare/containers";

export class Site extends Container {
  defaultPort = 8080;
  sleepAfter = "10m";
  enableInternet = false;
}

export default {
  fetch(request, env) {
    return getContainer(env.SITE, "site").fetch(request);
  },
};
