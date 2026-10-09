#include <signal.h>
#include <unistd.h>
static volatile sig_atomic_t deploy_stop = 0;
static void deploy_term(int sig) {
  (void)sig;
  deploy_stop = 1;
  const char message[] = "SIGNAL STOP REQUESTED\n";
  (void)write(STDOUT_FILENO, message, sizeof(message) - 1);
}
int camber_signal_install(void) {
  struct sigaction action = {0};
  action.sa_handler = deploy_term;
  sigemptyset(&action.sa_mask);
  return sigaction(SIGTERM, &action, NULL);
}
int camber_signal_requested(void) { return deploy_stop != 0; }
void camber_signal_request(void) { deploy_stop = 1; }

#ifndef CAMBER_SIGNAL_HOST
static Term deploy_install(Env e, Term *f, IoWork *w) {
  if (camber_signal_install() != 0) {
    perror("signal installation failed");
    _exit(1);
  }
  return term_pak(CID(Unit), 0);
}
static Term deploy_requested(Env e, Term *f, IoWork *w) {
  return term_pak(camber_signal_requested() ? CID(True) : CID(False), 0);
}
static Term deploy_request(Env e, Term *f, IoWork *w) {
  camber_signal_request();
  return term_pak(CID(Unit), 0);
}
static void __attribute__((constructor)) deploy_signals_use(void) {
  io_eff(CID(install), deploy_install);
  io_eff(CID(requested), deploy_requested);
  io_eff(CID(request), deploy_request);
}
#endif
