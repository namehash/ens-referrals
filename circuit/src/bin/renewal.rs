use axiom_sdk::cmd::run_cli;
use circuit::renewal::ENSRenewalInput;

fn main() {
    run_cli::<ENSRenewalInput>();
}
