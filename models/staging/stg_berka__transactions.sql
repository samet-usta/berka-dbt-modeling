with source as (

    select * from {{ source('berka', 'trans') }}

),

renamed as (

    select
        cast(trans_id as integer)       as transaction_id,
        cast(account_id as integer)     as account_id,
        strptime(date, '%y%m%d')::date  as transaction_date,

        case type
            when 'PRIJEM' then 'credit'
            when 'VYDAJ'  then 'debit'
            when 'VYBER'  then 'withdrawal'
            else type
        end as transaction_type,

        case nullif(trim(operation), '')
            when 'VYBER KARTOU'   then 'card_withdrawal'
            when 'VKLAD'          then 'cash_deposit'
            when 'PREVOD Z UCTU'  then 'collection_from_bank'
            when 'VYBER'          then 'cash_withdrawal'
            when 'PREVOD NA UCET' then 'remittance_to_bank'
            else nullif(trim(operation), '')
        end as operation,

        cast(amount as decimal(15,2))   as amount,
        cast(balance as decimal(15,2))  as balance,

        case nullif(trim(k_symbol), '')
            when 'POJISTNE'    then 'insurance'
            when 'SLUZBY'      then 'statement_fee'
            when 'UROK'        then 'interest'
            when 'SANKC. UROK' then 'penalty_interest'
            when 'SIPO'        then 'household'
            when 'DUCHOD'      then 'pension'
            when 'UVER'        then 'loan_payment'
            else nullif(trim(k_symbol), '')
        end as purpose,

        -- Karşı taraf banka ve hesap: VARCHAR kalır
        nullif(trim(bank), '')          as partner_bank,
        nullif(trim(account), '')       as partner_account,

        _loaded_at

    from source

)

select * from renamed
