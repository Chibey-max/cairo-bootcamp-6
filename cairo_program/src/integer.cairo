use core::result::Result;

#[executable]
fn main() {
    let result: u8 = add_num(5, 6);
    println!("The sum of x & y is: {}", result);
    assert(result == 11, 'invalid sum logic');

    let sub_result = sub_num(10, 5);
    match sub_result {
        Result::Ok(value) => {
            println!("Sub result is: {}", value);
            assert(value == 5, 'invalid sub');
        },
        Result::Err(err) => {
            println!("subtraction failed: {}", err);
            assert(false, 'unexpected error in sub_num');
        },
    }

    let mul_result: u8 = mul_num(5, 2);
    println!("Mul result of x & y is {}", mul_result);
    assert(mul_result == 10, 'invalid mul');

    let div_result = div_num(10, 0);
    match div_result {
        Result::Ok(value) => {
            println!("Div result of x & y is {}", value);
            assert(value == 1, 'division by zero');
        },
        Result::Err(err) => {
            println!("division failed: {}", err);
            assert(false, 'unexpected error in div_num');
        },
    }
}

fn add_num(x: u8, y: u8) -> u8 {
    x + y
}
#[cfg(test)]
mod tests {
    use core::result::Result;
    use super::{add_num, div_num, mul_num, sub_num};

    #[test]
    fn test_add_num() {
        let result = add_num(5, 6);
        assert(result == 11, 'invalid sum logic');
    }
    #[test]
    fn test_sub_num() {
        let result = sub_num(3, 1);
        match result {
            Result::Ok(value) => assert(value == 2, 'invalid subtraction logic'),
            Result::Err(_) => assert(false, 'unexpected error in sub_num'),
        }
    }
    #[test]
    fn test_mul_num() {
        let result = mul_num(2, 2);
        assert(result == 4, 'invalid multiplication logic');
    }
    #[test]
    fn test_div_num() {
        let result = div_num(6, 2);
        match result {
            Result::Ok(value) => assert(value == 3, 'invalid division logic'),
            Result::Err(_) => assert(false, 'unexpected error in div_num'),
        }
    }
}

fn sub_num(x: u8, y: u8) -> Result<u8, felt252> {
    if y > x {
        Result::Err('result would be negative')
    } else {
        Result::Ok(x - y)
    }
}

fn mul_num(x: u8, y: u8) -> u8 {
    x * y
}

fn div_num(x: u8, y: u8) -> Result<u8, felt252> {
    if y != 0 {
        Result::Ok(x / y)
    } else {
        Result::Err('not divisible by zero')
    }
}
