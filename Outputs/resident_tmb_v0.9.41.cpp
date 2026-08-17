// resident_tmb_v0.9.41.cpp
// TMB backend for resident_pipeline_v0.9.41.
//
// Compile from R with:
//   TMB::compile("resident_tmb.cpp")
//   dyn.load(TMB::dynlib("resident_tmb"))

#include <TMB.hpp>

namespace resident_tmb_internal {
template<class Type>
Type logspace_add(Type a, Type b) {
  return ::logspace_add(a, b);
}
}

template<class Type>
vector<Type> softmax_vec(vector<Type> eta) {
  Type m = eta.maxCoeff();
  vector<Type> out(eta.size());
  Type denom = Type(0);
  for (int i = 0; i < eta.size(); i++) {
    out(i) = exp(eta(i) - m);
    denom += out(i);
  }
  for (int i = 0; i < eta.size(); i++) out(i) /= denom;
  return out;
}

template<class Type>
Type objective_function<Type>::operator() () {
  DATA_ARRAY(y);                 // N x Kp x Jmax, missing coded < 0
  DATA_MATRIX(occasion_index);   // Kp x Jmax, 0-based occasion index, missing < 0
  DATA_MATRIX(X_detection);      // (N*T) x P detection design
  DATA_INTEGER(N);
  DATA_INTEGER(Kp);
  DATA_INTEGER(Jmax);
  DATA_INTEGER(S);
  DATA_INTEGER(Tobs);
  DATA_IVECTOR(unavailable);     // length S, 1 if unavailable/outside
  DATA_VECTOR(initial_probs);    // length S
  DATA_INTEGER(estimate_transition);
  DATA_INTEGER(re_individual_detection);
  DATA_INTEGER(re_primary_detection);
  DATA_INTEGER(re_state_detection);

  PARAMETER_VECTOR(beta_detection);
  PARAMETER_VECTOR(trans_par);   // S * (S - 1) if estimated
  PARAMETER_VECTOR(u_individual);
  PARAMETER_VECTOR(u_primary);
  PARAMETER_VECTOR(u_state);
  PARAMETER(log_sigma_individual_detection);
  PARAMETER(log_sigma_primary_detection);
  PARAMETER(log_sigma_state_detection);

  Type nll = Type(0);

  Type sigma_i = exp(log_sigma_individual_detection);
  Type sigma_k = exp(log_sigma_primary_detection);
  Type sigma_s = exp(log_sigma_state_detection);

  if (re_individual_detection) {
    for (int i = 0; i < u_individual.size(); i++) nll -= dnorm(u_individual(i), Type(0), sigma_i, true);
  }
  if (re_primary_detection) {
    for (int k = 0; k < u_primary.size(); k++) nll -= dnorm(u_primary(k), Type(0), sigma_k, true);
  }
  if (re_state_detection) {
    for (int s = 0; s < u_state.size(); s++) nll -= dnorm(u_state(s), Type(0), sigma_s, true);
  }

  matrix<Type> Psi(S, S);
  if (estimate_transition) {
    int pos = 0;
    for (int r = 0; r < S; r++) {
      vector<Type> eta(S);
      for (int c = 0; c < S - 1; c++) eta(c) = trans_par(pos++);
      eta(S - 1) = Type(0);
      vector<Type> row = softmax_vec(eta);
      for (int c = 0; c < S; c++) Psi(r, c) = row(c);
    }
  } else {
    DATA_MATRIX(Psi_fixed);
    for (int r = 0; r < S; r++) for (int c = 0; c < S; c++) Psi(r, c) = Psi_fixed(r, c);
  }

  for (int i = 0; i < N; i++) {
    matrix<Type> logB(S, Kp);
    for (int s = 0; s < S; s++) for (int k = 0; k < Kp; k++) logB(s, k) = Type(0);

    for (int k = 0; k < Kp; k++) {
      for (int j = 0; j < Jmax; j++) {
        int occ = CppAD::Integer(occasion_index(k, j));
        if (occ < 0) continue;
        Type yy = y(i, k, j);
        if (yy < Type(0)) continue;
        int row = i * Tobs + occ;
        Type eta = Type(0);
        for (int p = 0; p < beta_detection.size(); p++) eta += X_detection(row, p) * beta_detection(p);
        if (re_individual_detection) eta += u_individual(i);
        if (re_primary_detection) eta += u_primary(k);
        Type p_base = invlogit(eta);
        for (int s = 0; s < S; s++) {
          if (unavailable(s) == 1) {
            if (yy > Type(0)) logB(s, k) += R_NegInf;
          } else {
            Type ps = p_base;
            if (re_state_detection) ps = invlogit(eta + u_state(s));
            logB(s, k) += yy > Type(0) ? log(ps) : log(Type(1) - ps);
          }
        }
      }
    }

    vector<Type> logalpha(S);
    for (int s = 0; s < S; s++) logalpha(s) = log(initial_probs(s)) + logB(s, 0);

    for (int k = 1; k < Kp; k++) {
      vector<Type> next(S);
      for (int s = 0; s < S; s++) {
        Type acc = R_NegInf;
        for (int r = 0; r < S; r++) acc = resident_tmb_internal::logspace_add(acc, logalpha(r) + log(Psi(r, s)));
        next(s) = acc + logB(s, k);
      }
      logalpha = next;
    }

    Type lli = R_NegInf;
    for (int s = 0; s < S; s++) lli = resident_tmb_internal::logspace_add(lli, logalpha(s));
    nll -= lli;
  }

  ADREPORT(sigma_i);
  ADREPORT(sigma_k);
  ADREPORT(sigma_s);
  ADREPORT(Psi);
  return nll;
}
