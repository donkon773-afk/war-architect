/* PURE shared cancellation gate, including the vehicle crew's player token. */
params ["_token","_leaseToken","_until","_now","_sameLease","_conscious","_ownerToken","_leaseOwnerToken"];
_token == _leaseToken && {_now < _until} && {_sameLease} && {_conscious} && {_ownerToken == _leaseOwnerToken}
