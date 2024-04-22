use axiom_circuit::{
    input::flatten::FixLenVec,
    types::{AxiomCircuitParams, AxiomV2DataAndResults},
    utils::get_provider,
};
use axiom_sdk::{
    axiom::AxiomCompute, ethers::types::H256, halo2_base::gates::circuit::BaseCircuitParams,
};

use crate::{renewal::ENSRenewalInput, tests::utils::calculate_claim_id};

use super::utils::pad_input;

fn get_input(block_number: Vec<usize>, tx_idx: Vec<usize>, log_idx: Vec<usize>) -> ENSRenewalInput {
    let (block_numbers, tx_idxs, log_idxs) = pad_input(block_number.clone(), tx_idx, log_idx);
    ENSRenewalInput {
        block_numbers: FixLenVec::new(block_numbers).unwrap(),
        tx_idxs: FixLenVec::new(tx_idxs).unwrap(),
        log_idxs: FixLenVec::new(log_idxs).unwrap(),
        num_claims: block_number.len(),
    }
}

fn get_circuit_output(
    block_number: Vec<usize>,
    tx_idx: Vec<usize>,
    log_idx: Vec<usize>,
) -> AxiomV2DataAndResults {
    let params = BaseCircuitParams {
        k: 12,
        num_advice_per_phase: vec![4],
        num_fixed: 1,
        num_lookup_advice_per_phase: vec![1],
        lookup_bits: Some(11),
        num_instance_columns: 1,
    };

    let provider = get_provider();
    let input = get_input(block_number, tx_idx, log_idx);
    let compute = AxiomCompute::<ENSRenewalInput>::new()
        .use_params(AxiomCircuitParams::Base(params))
        .use_provider(provider)
        .use_inputs(input);
    let circuit = compute.circuit();
    circuit.scaffold_output()
}

#[test]
fn test_referral_id() {
    // https://sepolia.etherscan.io/tx/0xcae128087515abfcff4731ccd815f2c19611f882842c030af1e1bdb6e485af97#eventlog
    let output = get_circuit_output(vec![5203518], vec![112], vec![1]);
    let expiry = 1769941548;
    assert_eq!(
        output.compute_results[2],
        H256::from_low_u64_be(expiry % 86400)
    );
}

#[test]
fn test_claim_id() {
    let block_number = 5203518;
    let tx_idx = 112;
    let log_idx = 1;
    let output = get_circuit_output(vec![block_number], vec![tx_idx], vec![log_idx]);
    let claim_id = calculate_claim_id(block_number, tx_idx, log_idx);
    assert_eq!(output.compute_results[0], claim_id);
    assert_eq!(output.compute_results[1], claim_id);
}

#[test]
fn test_full_fee() {
    // https://sepolia.etherscan.io/tx/0xcae128087515abfcff4731ccd815f2c19611f882842c030af1e1bdb6e485af97#eventlog
    let output = get_circuit_output(vec![5203518], vec![112], vec![1]);
    let full_cost: usize = 3187500000003559;
    assert_eq!(
        output.compute_results[3],
        H256::from_low_u64_be(full_cost as u64)
    );
}

#[test]
fn test_4_char_fee() {
    // https://sepolia.etherscan.io/tx/0x656ae52987a71d91aeebdb5fb0a62a485958125445a37aa8314593dcbacc91b4#eventlog
    let output = get_circuit_output(vec![5647069], vec![120], vec![1]);
    let full_cost: usize = 713999999999953018;
    let four_char_cost = full_cost / 32;
    assert_eq!(
        output.compute_results[3],
        H256::from_low_u64_be(four_char_cost as u64)
    );
}

#[test]
fn test_sum_volume() {
    // tx1: https://sepolia.etherscan.io/tx/0xcae128087515abfcff4731ccd815f2c19611f882842c030af1e1bdb6e485af97#eventlog
    // tx2: https://sepolia.etherscan.io/tx/0x656ae52987a71d91aeebdb5fb0a62a485958125445a37aa8314593dcbacc91b4#eventlog
    let output = get_circuit_output(vec![5203518, 5647069], vec![112, 120], vec![1, 1]);
    let volume = 3187500000003559 + (713999999999953018 / 32);
    assert_eq!(output.compute_results[3], H256::from_low_u64_be(volume));
}
