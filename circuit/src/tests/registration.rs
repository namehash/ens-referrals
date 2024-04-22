use axiom_circuit::{
    input::flatten::FixLenVec,
    types::{AxiomCircuitParams, AxiomV2DataAndResults},
    utils::get_provider,
};
use axiom_sdk::{
    axiom::AxiomCompute, ethers::types::H256, halo2_base::gates::circuit::BaseCircuitParams,
};

use crate::{registration::ENSRegistrationInput, tests::utils::calculate_claim_id};

use super::utils::pad_input;

fn get_input(
    block_number: Vec<usize>,
    tx_idx: Vec<usize>,
    log_idx: Vec<usize>,
) -> ENSRegistrationInput {
    let (block_numbers, tx_idxs, log_idxs) = pad_input(block_number.clone(), tx_idx, log_idx);
    ENSRegistrationInput {
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
    let compute = AxiomCompute::<ENSRegistrationInput>::new()
        .use_params(AxiomCircuitParams::Base(params))
        .use_provider(provider)
        .use_inputs(input);
    let circuit = compute.circuit();
    circuit.scaffold_output()
}

#[test]
fn test_referral_id() {
    let output = get_circuit_output(vec![5147955], vec![31], vec![0]);
    assert_eq!(output.compute_results[2], H256::from_low_u64_be(1));
}

#[test]
fn test_claim_id() {
    let block_number = 5147955;
    let tx_idx = 31;
    let log_idx = 0;
    let output = get_circuit_output(vec![block_number], vec![tx_idx], vec![log_idx]);
    let claim_id = calculate_claim_id(block_number, tx_idx, log_idx);
    assert_eq!(output.compute_results[0], claim_id);
    assert_eq!(output.compute_results[1], claim_id);
}

#[test]
fn test_full_fee() {
    // https://sepolia.etherscan.io/tx/0x223e91d10d5786a33014646ae11fa58306672a3faebaccf677ff9c3e232505d8#eventlog
    let output = get_circuit_output(vec![5750508], vec![6], vec![10]);
    let full_cost: usize = 0x1b40f2169b330;
    assert_eq!(
        output.compute_results[3],
        H256::from_low_u64_be(full_cost as u64)
    );
}

#[test]
fn test_4_char_fee() {
    // https://sepolia.etherscan.io/tx/0x223e91d10d5786a33014646ae11fa58306672a3faebaccf677ff9c3e232505d8#eventlog
    let output = get_circuit_output(vec![5750330], vec![8], vec![10]);
    let full_cost: usize = 38356164383559120;
    let four_char_cost = full_cost / 32;
    assert_eq!(
        output.compute_results[3],
        H256::from_low_u64_be(four_char_cost as u64)
    );
}

#[test]
fn test_sum_volume() {
    // tx1: https://sepolia.etherscan.io/tx/0x223e91d10d5786a33014646ae11fa58306672a3faebaccf677ff9c3e232505d8#eventlog
    // tx2: https://sepolia.etherscan.io/tx/0x3fbd860c43626d7f4ca31a002cce9a396c7c3fa5582352a5c70dc90049d13c3b#eventlog
    let output = get_circuit_output(vec![5750330, 5750508], vec![8, 6], vec![10, 10]);
    let volume = 0x44225d3883a6e + 0x1b40f2169b330;
    assert_eq!(output.compute_results[3], H256::from_low_u64_be(volume));
}
