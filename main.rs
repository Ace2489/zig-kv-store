use json::JsonValue;
use std::env;
use std::fs;
use regex::Regex;

fn main() {
    // #[derive(Debug)]
    enum QueryStep<'a>{
        Key(&'a str),
        Index(usize)
    }

    let Some(json_path) = env::args().nth(1) else {
        panic!("No file to query")
    };

    let Some(query) = env::args().nth(2) else {
        panic!("No query to execute")
    };

    let re = Regex::new(r"([a-zA-Z0-9_]+)|\[(\d+)\]").unwrap();

    let Ok(json_str) = fs::read_to_string(&json_path) else {
        panic!("No file named {json_path:?} exists")
    };

    let parsed = json::parse(&json_str.to_string());
    let mut queries:Vec<QueryStep> = Vec::new();

    for cap in re.captures_iter(query.as_str()){
        if let Some(val) = cap.get(1){
            queries.push(QueryStep::Key(val.as_str()));
        }
        else if let Some(val) = cap.get(2){
            let Ok(val) = val.as_str().parse() else {panic!("An invalid index was matched by the regex")};
            queries.push(QueryStep::Index(val));
        }
    }

    let mut value = &parsed.expect(format!("Something went wrong while parsing {json_path:#?}").as_str());

    for query in queries{
        match query {
            QueryStep::Key(key)=>{
                let JsonValue::Object(obj) = value else { panic!("A json key was given but the current data position does not have a key")};
                value = &obj[key];
                if value.is_null(){break;}
            },
            QueryStep::Index(index)=>{
                let JsonValue::Array(array) = value else {panic!("A json array index was given but the current data position is not an array")};
                value = &array[index];
                if value.is_null(){break;}
            }
        }
    }

    if value.is_null(){println!("Your query did not return any result!");return};
    println!("{:#}",value.dump());

}
