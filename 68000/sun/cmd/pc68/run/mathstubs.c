/* This module contains stubs for math routines which just
 * call the ones in libc. -Per Bothner. June 1982.
 *
 * Because c always uses double for real parameters,
 * while (this verion of) Pascal does not, we push an extra zero longword.
 */

_sin(r) { return (sin(r, 0)); }
_cos(r) { return (cos(r, 0)); }
_atn(r) { return (atan(r, 0)); }
_exp(r) { return (exp(r, 0)); }
_log(r) { return (log(r, 0)); }
_sqt(r) { return (sqrt(r, 0)); }
