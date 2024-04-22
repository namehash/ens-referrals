use axiom_sdk::ethers::types::{BigEndianHash, H256, U256};

pub fn pad_input(
    block_number: Vec<usize>,
    tx_idx: Vec<usize>,
    log_idx: Vec<usize>,
) -> (Vec<usize>, Vec<usize>, Vec<usize>) {
    let mut block_numbers = block_number.clone();
    block_numbers.resize(10, block_number[0]);
    let mut tx_idxs = tx_idx.clone();
    tx_idxs.resize(10, tx_idx[0]);
    let mut log_idxs = log_idx.clone();
    log_idxs.resize(10, log_idx[0]);

    (block_numbers, tx_idxs, log_idxs)
}

pub fn calculate_claim_id(block_number: usize, tx_idx: usize, log_idx: usize) -> H256 {
    let claim_id_value = U256::from(block_number) * U256::from(2).pow(U256::from(128))
        + U256::from(tx_idx) * U256::from(2).pow(U256::from(64))
        + log_idx;
    H256::from_uint(&claim_id_value)
}
