function pass_match(){
    pass_1 = document.getElementById("password").value 
    pass_2 = document.getElementById("confirm_password").value 
    console.log(pass_1)
    console.log(pass_2)

    if (pass_2 == pass_1){
        document.getElementById("password_warning").style.display="none";
        document.getElementById("user_submit_btn").style.display="block";
    }
    else{
        document.getElementById("password_warning").style.display="block";
        document.getElementById("user_submit_btn").style.display="none";
    }
}

function destroy_el(){
    el = document.getElementById("flash_message_container")
    el.style.display='none';
}





function switch_page(arg_string){
    console.log(arg_string);
    url_string = "/"+ arg_string
    console.log(url_string);
    window.location.href = url_string
}

function make_call(arg_string){
    url_string = "tel:"+arg_string;
    console.log("function called");
    window.location.href = url_string;
}

function mail_to(arg_string){
    url_string = "mailto:"+arg_string;
    console.log("function mailed");
    window.location.href = url_string;
}

function redirect_ig(){
    url_string="https://www.instagram.com/wowza.africa/";
    console.log("function redirect ig called");
    window.location.href = url_string;
}

function redirect_whatsapp(arg_string){
    url_string = "https://wa.me/"+arg_string
    console.log("redirecting to whatsapp");
    window.location.href = url_string;
}





function storageAvailable(type){
    var storage;
    try {
        storage = window[type];
        var x = '__storage_test__';
        storage.setItem(x,x);
        storage.removeItem(x);
        return true;
    }
    catch(e) {
        return e instanceof DOMException && (
            //everything except Firefox
            e.code === 22 ||
            // Firefox
            e.code === 1014 ||
            //test name field too, because code might not be present
            //everything except Firefox
            e.name === 'QuotaExceededError' ||
            // Firefox
            e.name === 'NS_ERROR_DOM_QUOTA_REACHED') &&
            
            (storage && storage.length !== 0);
    }
}






function reset_app(){
    localStorage.clear()
    init_counter_app()
    init_display()
}

function init_counter_app() {
    if (storageAvailable('localStorage')) {
        console.log("localStorage available");
        
        const initialSaleData = {
            sale_clerk: '',
            sale_total: 0.0,
            sale_paid_amount: 0.0,
            sale_balance: 0.0,
            payment_method: null,
            payment_reference: null,
            payment_gateway: null,
            item_array: []
        };
        
        localStorage.setItem('current_items_pack', JSON.stringify(initialSaleData));
    } else {
        console.log("localStorage not available");
    } 
}


function init_display(){
    document.getElementById('totals_heading').innerHTML = 'Total : '+ 0.00
    document.getElementById('tbody').innerHTML = ''
}


function togglePaymentFields() {
    var paymentMethodSelect = document.getElementById("payment_method");
    var selectedPaymentMethod = paymentMethodSelect.value;
    
    var cashFields = document.getElementById("cash_fields");
    var mpesaFields = document.getElementById("mpesa_fields");
    
    if (selectedPaymentMethod === "cash") {
        cashFields.style.display = "block";
        mpesaFields.style.display = "none";
    } else if (selectedPaymentMethod === "mpesa") {
        cashFields.style.display = "none";
        mpesaFields.style.display = "block";
    }
}


// Call togglePaymentFields initially to show/hide fields based on default selection
togglePaymentFields();



function fetch_item(item_code) {
    if (item_code.trim() !== '') {
        const url = `${window.location.origin}/item/${item_code}`;

        fetch(url)
        .then(response => response.json())
        .then(item_data => {
            if (!item_data.error && item_data.id) {
                add_item(item_data.id, item_data.name, item_data.price);
            }
        })
        .catch(err => {
            console.log('Error fetching item:', err);
            flash_message("Invalid input or item not found");
        });
    } else {
        console.log('Invalid input');
        flash_message("Invalid input");
    }
}


function add_item(item_id, item_name, item_price){
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    let item_string = `${item_id}:${item_name}:${item_price}`
    sale_object.item_array.push(item_string) 
    localStorage.setItem('current_items_pack', JSON.stringify(sale_object))
    display_items()
}

function delete_this_entry(entry){
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    let index = entry - 1
    sale_object.item_array.splice(index,1)
    localStorage.setItem('current_items_pack', JSON.stringify(sale_object))
    document.getElementById('code_input').focus()
    display_items()
}


function display_items(){
    console.log('display items called')
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    document.getElementById('tbody').innerHTML=''
    for(let i=0; i<sale_object.item_array.length; i++){
        item_string_split = sale_object.item_array[i].split(':')
        let item_listing_index = i+1 
        inner_html_string = '<td>' + item_listing_index + '</td>' + '<td>' + item_string_split[1] + '</td>' + '<td>' + item_string_split[2] + '</td>' + '<td>' + '<span class="" onclick="delete_this_entry('+ item_listing_index +')">'+' <i class="fa fa-times-circle" style="font-weight: bolder;"></i>'+'</span>'+'</td>'
        let row = document.createElement('tr')
        row.innerHTML = inner_html_string
        document.getElementById('tbody').appendChild(row)
    }
    get_total()
}

function list_sale_items(){
    console.log('list sale items')
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    document.getElementById('checkout_items_table_body').innerHTML=''
    for(let i=0; i<sale_object.item_array.length; i++){
        item_string_split = sale_object.item_array[i].split(":")
        let item_listing_index = i+1
        inner_html_string = '<td>' + item_listing_index + '</td>' + '<td>' + item_string_split[1] + '</td>' + '<td>'+ item_string_split[2] + '</td>'
        let row = document.createElement('tr')
        row.innerHTML = inner_html_string
        document.getElementById('checkout_items_table_body').appendChild(row)
    }

    get_sale_total()
}


function get_total(){
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    let sale_total = 0.00
    for (let i=0; i<sale_object.item_array.length; i++){
        item_string_split = sale_object.item_array[i].split(':')
        sale_total = sale_total + Number(item_string_split[2])
    }
    sale_object.sale_total = sale_total
    localStorage.setItem('current_items_pack', JSON.stringify(sale_object))
    document.getElementById('totals_heading').innerHTML = 'Total : '+ sale_total
    document.getElementById('sale_total_display2').innerHTML = `<b>Total : ${sale_total}</b>`

    return sale_total
    

}

function updateTotals() {
    // Get elements by their IDs
    var totalRow = document.getElementById("total_row");
    var subTotalRow = document.getElementById("sub_total_row");
    var vatTotalRow = document.getElementById("vat_total_row");

    // Check if totalRow exists and has non-empty text content
    if (totalRow && totalRow.textContent.trim() !== '') {
        // Log the value of total_row
        console.log(`Total Row Value: ${totalRow.textContent.trim()}`);

        // Get the trimmed content of totalRow
        var trimmedContent = totalRow.textContent.trim();

        // Remove non-numeric characters (leaving only digits and dots)
        var numericContent = trimmedContent.replace(/[^\d.]/g, '');

        // Attempt to parse the content as a float
        var totalValue = parseFloat(numericContent);

        // Check if parsing was successful
        if (!isNaN(totalValue)) {
            // Log the converted total value
            console.log(`Converted Total Value: ${totalValue}`);

            // Calculate VAT total (16% of total_row)
            var vatTotalValue = totalValue * 0.16;

            // Calculate sub-total (total_row - vat_total_row)
            var subTotalValue = totalValue - vatTotalValue;

            // Update the text content of sub_total_row and vat_total_row
            subTotalRow.textContent = `Sub Total: ${subTotalValue.toFixed(2)}`; // Adjust decimal places as needed
            vatTotalRow.textContent = `Vat Total: ${vatTotalValue.toFixed(2)}`; // Adjust decimal places as needed
        } else {
            console.log("Error: Total Row content could not be parsed as a number.");
            // If parsing fails, reset sub_total_row and vat_total_row
            subTotalRow.textContent = "0.00";
            vatTotalRow.textContent = "0.00";
        }
    } else {
        console.log("Total Row is missing or empty.");
        // If total_row is missing or empty, reset sub_total_row and vat_total_row
        subTotalRow.textContent = "0.00";
        vatTotalRow.textContent = "0.00";
    }
}




function get_sale_total(){
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    let sale_total = 0.00
    for (let i=0; i<sale_object.item_array.length; i++){
        item_string_split = sale_object.item_array[i].split(':')
        sale_total = sale_total + Number(item_string_split[2])
    }
    sale_object.sale_total = sale_total
    localStorage.setItem('current_items_pack', JSON.stringify(sale_object))

    let cell_string = `Total: ${sale_total}`
    document.getElementById('total_row').innerHTML=''
    document.getElementById('total_row').innerHTML=cell_string
    updateTotals()

}

function update_payment() {
    var paymentMethodSelect = document.getElementById("payment_method");
    var paymentInput = document.getElementById("checkout_payment_input");
    var mpesaGatewaySelect = document.getElementById("mpesa_gateway");
    var mpesaPaymentInput = document.getElementById("mpesa_payment_input");
    var mpesaReferenceInput = document.getElementById("mpesa_reference_input");
    var recordingUserInput = document.getElementById('recording_user'); // Assuming 'recording_user' is an input element

    var selectedPaymentMethod = paymentMethodSelect.value;
    var input_value;
    
    if (selectedPaymentMethod === "cash") {
        input_value = paymentInput.value;
    } else if (selectedPaymentMethod === "mpesa") {
        input_value = mpesaPaymentInput.value;
    }
    
    var recordingUser = recordingUserInput.value;
    
    console.log("update_payment!");
    console.log("Recording User:", recordingUser);
    console.log("Selected Payment Method:", selectedPaymentMethod);
    console.log("Payment Input Value:", paymentInput.value);
    console.log("MPESA Gateway Select Value:", mpesaGatewaySelect.value);
    console.log("MPESA Payment Input Value:", mpesaPaymentInput.value);
    console.log("MPESA Reference Input Value:", mpesaReferenceInput.value);
    
    input_value = Number(input_value);

    console.log("converted value");
    console.log(input_value);

    set_payment(recordingUser, input_value, selectedPaymentMethod, mpesaGatewaySelect, mpesaReferenceInput);
}





function set_payment(recordingUser, input, selectedPaymentMethod, mpesaGatewaySelect, mpesaReferenceInput) {
    console.log("set payment");

    let sale_object = JSON.parse(localStorage.getItem("current_items_pack"));
    console.log(`current sale total is : ${sale_object.sale_total}`);

    if (isNaN(input)) {
        document.getElementById("input_error").style.display = "block";
        return; // Exit the function if input is not a valid number
    }

    if (selectedPaymentMethod === "cash") {
        if (!recordingUser || !input) {
            console.log("Empty arguments detected 1");
            console.log(`checking value recording user : ${recordingUser}`);
            return;
        }
        
        if (input >= sale_object.sale_total) {
            document.getElementById("input_error").style.display = "none";
            
            sale_object.sale_clerk = recordingUser;
            sale_object.sale_payment = input;
            sale_object.payment_method = "CASH"; // Update payment method
            sale_object.payment_reference = "NILL"; // Clear payment reference for cash
            sale_object.payment_gateway = "0000-0000"; // Clear payment gateway for cash
            console.log("sale payment");
            console.log(sale_object);
            localStorage.setItem("current_items_pack", JSON.stringify(sale_object));
            document.getElementById("checkout_button_container").style.display = "block";
            get_change();
        } else {
            document.getElementById("input_error").style.display = "block";
            document.getElementById("input_error").innerHTML = "Payment is not enough";
            document.getElementById("checkout_button_container").style.display = "none";
        }
    } else if (selectedPaymentMethod === "mpesa") {
        if (!recordingUser || !input || !mpesaGatewaySelect || !mpesaReferenceInput) {
            console.log("Empty arguments detected 2");
            return;
        }
        
        let selectedMpesaGateway = mpesaGatewaySelect.value;
        let selectedMpesaReference = mpesaReferenceInput.value;
        
        sale_object.sale_clerk = recordingUser;
        sale_object.sale_payment = input;
        sale_object.payment_method = "MPESA"; // Update payment method
        sale_object.payment_reference = selectedMpesaReference; // Update payment reference for MPESA
        sale_object.payment_gateway = selectedMpesaGateway; // Update payment gateway for MPESA
        console.log("sale payment");
        console.log(sale_object);
        localStorage.setItem("current_items_pack", JSON.stringify(sale_object));
        document.getElementById("checkout_button_container").style.display = "block";
        get_change();
    }
}





function get_change() {
    let sale_object = JSON.parse(localStorage.getItem("current_items_pack"));
    let sale_change = sale_object.sale_payment - sale_object.sale_total;

    if (sale_change >= 0) {
        document.getElementById("sale_change_display").innerHTML = `<b>Change : ${sale_change.toFixed(2)}</b>`;
    } else {
        document.getElementById("sale_change_display").innerHTML = "<b>Change : 0.00</b>";
    }

    document.getElementById("cash_row").innerHTML = `Cash : ${sale_object.sale_payment.toFixed(2)}`;
    document.getElementById("change_row").innerHTML = `Change : ${Math.abs(sale_change).toFixed(2)}`;

    sale_object.sale_change = sale_change;
    localStorage.setItem("current_items_pack", JSON.stringify(sale_object));

    insertRandomNumber();
}

// Function to generate a random 10-digit non-floating-point number
function generateRandomNumber() {
    var min = 1000000000; // Minimum 10-digit number
    var max = 9999999999; // Maximum 10-digit number
    var randomNumber = Math.floor(Math.random() * (max - min + 1)) + min;
    return randomNumber;
}

// Function to generate and display a barcode based on the provided number
function generateBarcode(randomNumber) {
    // Generate barcode using JsBarcode library
    JsBarcode("#barcode_area", randomNumber.toString(), {
        format: "CODE128", // You can use other barcode formats supported by JsBarcode
        displayValue: true // Show the value of the barcode below it
    });
}


// Function to generate and display a QR code based on the provided content
function generateQRCode(content) {
    // Create a new QRCode instance
    var qrCode = new QRCode(document.getElementById("qrcode_area"), {
        text: content, // Content for the QR code
        width: 128,    // Width of the QR code
        height: 128,   // Height of the QR code
        colorDark: "#000000", // Color of the dark blocks
        colorLight: "#ffffff", // Color of the light blocks
        correctLevel: QRCode.CorrectLevel.H // Error correction level (H: High)
    });
}


// Function to insert the generated random number into the element with ID "tranx_code"
function insertRandomNumber() {
    var tranxCodeElement = document.getElementById("tranx_code");
    if (tranxCodeElement) {
        rand_num = generateRandomNumber();
        tranxCodeElement.textContent = rand_num;
        generateBarcode(rand_num)
        generateQRCode(rand_num)
    } else {
        console.log("Element with ID 'tranx_code' not found.");
    }
}



function add_sale_record() {
    console.log('Adding sale record');

    const current_sale_clerk = document.getElementById('user_name_span').innerHTML;
    console.log(`User: ${current_sale_clerk}`);

    const sale_object = JSON.parse(localStorage.current_items_pack);
    console.log('Sale object before sending to server:');
    console.log(sale_object);

    const payload = {
        sale_clerk: current_sale_clerk,
        sale_total: sale_object.sale_total,
        sale_paid_amount: sale_object.sale_payment,
        sale_balance: sale_object.sale_change,
        payment_method: sale_object.payment_method,
        payment_reference: sale_object.payment_reference,
        payment_gateway: sale_object.payment_gateway, // Updated to 'payment_gateway'
        items_array:sale_object.item_array
    };

    const url = `${window.location.origin}/add_sale_record`;
    fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    })
    .then(resp => {
        console.log(resp.status);
        return resp.json();
    })
    .then(data => {
        console.log(data);
        if (data.status === 'failed') {
            console.log('Sale record addition failed');
            // You can choose to display an error message or take other actions here
        } else {
            console.log('Sale record added successfully');
            const elementsToHide = [
                'back_button_container',
                'checkout_sale',
                'add_btn_container',
                'checkout_button_container'
            ];
            const elementsToShow = ['clear_button_container', 'print_button_container'];

            elementsToHide.forEach(id => {
                const element = document.getElementById(id);
                if (element) {
                    element.style.display = 'none';
                }
            });

            elementsToShow.forEach(id => {
                const element = document.getElementById(id);
                if (element) {
                    element.style.display = 'block';
                }
            });
        }
    })
    .catch(error => {
        console.log('Error:', error);
        // Handle the error as needed
    });
}



function clear_sale(){
    console.log('clearing sales...')
    reset_app()
    window.location = '/'

}


function login_disappear(){
    document.getElementById("login").style.display="none";
    document.getElementById("cancel").style.display="block"
}

function cancel_disappear(){
    document.getElementById("cancel").style.display="none";
    document.getElementById("login").style.display="block";
}

function switch_input_mode(){
    console.log('switching entry.....')
    text_value = document.getElementById('switch_btn').children[0].children[0].innerHTML
    console.log(text_value)
    if(text_value == 'Manual'){
        let new_text_value = 'Auto';
        document.getElementById('auto_sale').style.display='none';
        document.getElementById('manual_sale').style.display='block';
        document.getElementById('code_input2').focus()
        document.getElementById('switch_btn').children[0].children[0].innerHTML = new_text_value

    }
    else{
        let new_text_value = 'Manual';
        document.getElementById('manual_sale').style.display='none';
        document.getElementById('auto_sale').style.display='block';
        document.getElementById('code_input').focus();
        document.getElementById('switch_btn').children[0].children[0].innerHTML = new_text_value

    }
}




function upload_item_code(){
    var input = document.getElementById('code_input')
    var input_value = input.value
    if (input_value !==''){
        fetch_item(input_value)
        input.value = ''
    }
    else{
        // flash_message('input is empty')
    }
}


function upload_item_code2(){
    console.log('uploading item_code 2')
    var input = document.getElementById('code_input2')
    var input_value = input.value
    if (input_value ===''){
        // flash_message('input is empty')
    }
    else{
        fetch_item(input_value)
        input.value = ''
    }
}

function flash_message(message_string){
    document.getElementById('sale_flash_message_container').style.display='block';
    var message_board = document.getElementById('message_board') 
    message_board.innerHTML = message_string
}

function destroy_flash(){
    el = document.getElementById("sale_flash_message_container");
    el.style.display='none';
    document.getElementById('code_input').focus()
}


function switch_to_checkout(){
    let sale_object = JSON.parse(localStorage.getItem('current_items_pack'))
    if(sale_object.item_array.length != 0){
        document.getElementById('sale_container').style.display = 'none';
        let d = new Date();
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

        list_sale_items()
        document.getElementById('serve_time').innerHTML = `${d.getDate()}  : ${months[d.getMonth()]} : ${d.getFullYear()} : ${d.getHours()} : ${d.getMinutes()}`;
        document.getElementById('checkout_container').style.display = 'block';
        document.getElementById('checkout_payment_input').focus()
        
    }
    document.getElementById('code_input').focus()
    
}

function switch_back_from_checkout(){
    document.getElementById('checkout_container').style.display = 'none';
    document.getElementById('sale_container').style.display = 'block';
    document.getElementById('code_input').focus()
}



// Backup init
function init_users(key) {
    console.log("Initializing users");

    const currentOrigin = window.location.origin;

    fetch(`${currentOrigin}/init_users`, {
        method: "POST",
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            shop_api_key: key
        })
    })
    .then(response => response.json())
    .then(data => {
        console.log(data);
    })
    .catch(error => {
        console.error("Error initializing users:", error);
    });
}



function start_pdf_export() {
    console.log("Starting PDF export");

    const currentOrigin = window.location.origin;

    fetch(`${currentOrigin}/get_all_transactions_pdf`, {
        method: "GET",
        responseType: "blob" // Specify that the response will be a binary blob
    })
    .then(response => response.blob())
    .then(blob => {
        // Create a download link
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.style.display = "none";
        a.href = url;
        a.download = "transactions.pdf"; // Set the filename for the downloaded PDF
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
    })
    .catch(error => {
        console.error("Error exporting PDF:", error);
    });
}


// License utilites
function checkLicenseKeyLength(input) {
    var submitButton = document.getElementById('license_form_submit_btn');
    if (input.value.length === 16) {
        submitButton.style.display = 'block'; // Show the submit button
    } else {
        submitButton.style.display = 'none'; // Hide the submit button
    }
}