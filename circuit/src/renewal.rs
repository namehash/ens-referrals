use std::{fmt::Debug, str::FromStr};

use axiom_circuit::input::raw_input::RawInput;
use axiom_circuit::{axiom_eth::halo2curves::ff::Field, input::flatten::FixLenVec};
use axiom_sdk::ethers::types::H256;
use axiom_sdk::{
    axiom::{AxiomAPI, AxiomComputeFn, AxiomComputeInput, AxiomResult},
    ethers::abi::Address,
    halo2_base::{
        gates::{GateInstructions, RangeInstructions},
        AssignedValue,
        QuantumCell::Constant,
    },
    Fr,
};
use lazy_static::lazy_static;

const N: usize = 10;
const ENS_CONTRACT_ADDR: &str = "0xfed6a969aaa60e4961fcd3ebf1a2e8913ac65b72";

lazy_static! {
    static ref RENEWAL_EVENT_SCHEMA: H256 =
        H256::from_str("0x3da24c024582931cfaf8267d8ed24d13a82a8068d5bd337d30ec45cea4e506ae")
            .unwrap();
}

#[AxiomComputeInput]
pub struct ENSRenewalInput {
    pub block_numbers: FixLenVec<usize, N>,
    pub tx_idxs: FixLenVec<usize, N>,
    pub log_idxs: FixLenVec<usize, N>,
    pub num_claims: usize,
}

impl AxiomComputeFn for ENSRenewalInput {
    fn compute(
        api: &mut AxiomAPI,
        assigned_inputs: ENSRenewalCircuitInput<AssignedValue<Fr>>,
    ) -> Vec<AxiomResult> {
        let gate = api.range.gate();
        let two_pow_64 = gate.pow_of_two[64];
        let one = api.ctx().load_constant(Fr::one());

        api.range.check_less_than(
            api.ctx(),
            Constant(Fr::ZERO),
            assigned_inputs.num_claims,
            16,
        );

        api.range.check_less_than(
            api.ctx(),
            assigned_inputs.num_claims,
            Constant(Fr::from((N + 1) as u64)),
            16,
        );

        let mut ids = vec![];
        let mut in_range = vec![];
        for i in 0..N {
            let id_1 = gate.mul_add(
                api.ctx(),
                assigned_inputs.block_numbers[i],
                Constant(two_pow_64),
                assigned_inputs.tx_idxs[i],
            );
            let id = gate.mul_add(
                api.ctx(),
                id_1,
                Constant(two_pow_64),
                assigned_inputs.log_idxs[i],
            );
            let is_in_range = api.range.is_less_than(
                api.ctx(),
                Constant(Fr::from(i as u64)),
                assigned_inputs.num_claims,
                64,
            );
            in_range.push(is_in_range);
            let id_or_zero = gate.mul(api.ctx(), id, is_in_range);
            ids.push(id_or_zero);
        }

        for i in 1..N {
            let is_less = api.range.is_less_than(api.ctx(), ids[i - 1], ids[i], 192);
            let is_zero = gate.is_zero(api.ctx(), ids[i]);
            let is_less_or_not_in_range = gate.or(api.ctx(), is_less, is_zero);
            api.ctx().constrain_equal(&is_less_or_not_in_range, &one);
        }

        let mut volume = api.ctx().load_constant(Fr::ZERO);
        let two = api.ctx().load_constant(Fr::from(2u64));
        let three = api.ctx().load_constant(Fr::from(3u64));
        let four = api.ctx().load_constant(Fr::from(4u64));
        let six = api.ctx().load_constant(Fr::from(6u64));
        let byte_checks = [0x80, 0xe0, 0xf0, 0xf8, 0xfc]
            .iter()
            .map(|x| api.ctx().load_constant(Fr::from(*x as u64)))
            .collect::<Vec<_>>();
        let ens_addr = api
            .ctx()
            .load_constant(Address::from_str(ENS_CONTRACT_ADDR).unwrap().convert());
        let mut referrer_id = api.ctx().load_constant(Fr::from(0u64));

        for i in 0..N {
            let expires_256 = api
                .get_receipt(assigned_inputs.block_numbers[i], assigned_inputs.tx_idxs[i])
                .log(assigned_inputs.log_idxs[i])
                .data(two, Some(*RENEWAL_EVENT_SCHEMA));
            let expires = api.from_hi_lo(expires_256);
            let (_, referrer_id_from_expires) = api.range.div_mod(api.ctx(), expires, 86400u64, 64);

            if i == 0 {
                referrer_id = referrer_id_from_expires;
            } else {
                api.ctx()
                    .constrain_equal(&referrer_id_from_expires, &referrer_id);
            }

            let emitter_256 = api
                .get_receipt(assigned_inputs.block_numbers[i], assigned_inputs.tx_idxs[i])
                .log(assigned_inputs.log_idxs[i])
                .address();
            let emitter = api.from_hi_lo(emitter_256);
            api.ctx().constrain_equal(&emitter, &ens_addr);

            let name = api
                .get_receipt(assigned_inputs.block_numbers[i], assigned_inputs.tx_idxs[i])
                .log(assigned_inputs.log_idxs[i])
                .data(four, None);

            let name_len_256 = api
                .get_receipt(assigned_inputs.block_numbers[i], assigned_inputs.tx_idxs[i])
                .log(assigned_inputs.log_idxs[i])
                .data(three, None);
            let name_len = api.from_hi_lo(name_len_256);

            let name_bytes_hi = api.to_bytes_be(name.hi(), 16);
            let name_bytes_lo = api.to_bytes_be(name.lo(), 16);
            let mut name_24_bytes = Vec::new();
            name_24_bytes.extend_from_slice(&name_bytes_hi);
            name_24_bytes.extend_from_slice(&name_bytes_lo[..8]);

            let mut len = api.ctx().load_constant(Fr::from(0u64));
            let mut skip = api.ctx().load_constant(Fr::from(0u64));

            // See https://etherscan.io/address/0x253553366da8546fc250f225fe3d25d0c782303b#code#F19#L1 for the ENS strlen function
            // Pseudocode:
            // bytes = name[0..24] //if name byte len is less than 24, the remaining bytes are 0
            // byteLen = len(name)
            // strlen, bytesToSkip = 0
            // for byte in bytes:
            //      if (bytesToSkip == 0 and i < byteLen):
            //          strlen += 1
            //          bytesToSkip = ... // if condition to determine how many chars to skip based on byte
            //      else:
            //          bytesToSkip -= 1
            for j in 0..24 {
                let j_constant = api.ctx().load_constant(Fr::from(j as u64));
                let byte = name_24_bytes[j];
                let is_less_than_checks = byte_checks
                    .iter()
                    .map(|check| api.range.is_less_than(api.ctx(), byte, *check, 8))
                    .collect::<Vec<_>>();
                let checks_sum = gate.sum(api.ctx(), is_less_than_checks);

                let in_bounds = api.range.is_less_than(api.ctx(), j_constant, name_len, 8);
                let should_not_skip = gate.is_zero(api.ctx(), skip);
                let should_add_len = gate.and(api.ctx(), should_not_skip, in_bounds);

                let char_num_bytes = gate.sub(api.ctx(), six, checks_sum);
                let char_num_bytes_or_zero = gate.mul(api.ctx(), char_num_bytes, should_not_skip);
                let skip_minus_one = gate.sub(api.ctx(), skip, one);
                skip = gate.add(api.ctx(), skip_minus_one, char_num_bytes_or_zero);
                len = gate.add(api.ctx(), len, should_add_len);
            }

            let amount_256 = api
                .get_receipt(assigned_inputs.block_numbers[i], assigned_inputs.tx_idxs[i])
                .log(assigned_inputs.log_idxs[i])
                .data(one, None);
            let amount = api.from_hi_lo(amount_256);

            let is_full_price = api.range.is_less_than(api.ctx(), four, len, 8);
            let is_three = gate.is_equal(api.ctx(), len, three);
            let is_four = gate.is_equal(api.ctx(), len, four);
            let indicator = vec![is_full_price, is_four, is_three];

            let (three_char_scaled_price, _) = api.range.div_mod(api.ctx(), amount, 128u64, 80);
            let (four_char_scaled_price, _) = api.range.div_mod(api.ctx(), amount, 32u64, 80);
            let prices = vec![amount, four_char_scaled_price, three_char_scaled_price];

            let scaled_price = gate.select_by_indicator(api.ctx(), prices, indicator);

            let amount_or_zero = gate.mul(api.ctx(), scaled_price, in_range[i]);
            volume = gate.add(api.ctx(), volume, amount_or_zero);
        }

        let num_claims_idx = gate.sub(api.ctx(), assigned_inputs.num_claims, one);
        let last_claim_id = gate.select_from_idx(api.ctx(), ids.clone(), num_claims_idx);

        vec![
            ids[0].into(),
            last_claim_id.into(),
            referrer_id.into(),
            volume.into(),
        ]
    }
}
