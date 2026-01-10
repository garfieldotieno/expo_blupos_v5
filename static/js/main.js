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
    console.log('Resetting app - clearing all state');

    // Clear localStorage completely
    localStorage.clear()

    // Reset to initial app state
    init_counter_app()
    init_display()

    // Clear any error messages
    const errorElement = document.getElementById("input_error");
    if (errorElement) {
        errorElement.style.display = "none";
    }

    // Reset payment method selection to default (cash)
    selectPaymentMethod('cash');

    // Ensure checkout button is visible but disabled (ready for payment input)
    const checkoutContainer = document.getElementById('checkout_button_container');
    const checkoutButton = checkoutContainer ? checkoutContainer.querySelector('.product_type') : null;
    const hintText = checkoutContainer ? checkoutContainer.querySelector('p') : null;

    if (checkoutContainer) {
        checkoutContainer.style.opacity = '0.5';
        checkoutContainer.style.pointerEvents = 'none';
        checkoutContainer.style.display = 'block'; // Ensure it's always visible
        console.log('✅ Checkout button container made visible');
    } else {
        console.log('❌ Checkout button container not found');
    }

    if (checkoutButton) {
        checkoutButton.style.backgroundColor = '#ccc';
        checkoutButton.style.cursor = 'not-allowed';
        console.log('✅ Checkout button styling reset');
    } else {
        console.log('❌ Checkout button not found');
    }

    if (hintText) {
        hintText.textContent = '💡 Add payment details first';
        hintText.style.color = '#666';
        console.log('✅ Hint text reset');
    } else {
        console.log('❌ Hint text not found');
    }

    console.log('App reset complete - checkout button visible but disabled, ready for new sale');

    // Final verification - ensure checkout button is visible
    setTimeout(() => {
        const finalCheckoutContainer = document.getElementById('checkout_button_container');
        if (finalCheckoutContainer) {
            if (finalCheckoutContainer.style.display === 'none') {
                console.log('❌ Checkout button was hidden - forcing visibility');
                finalCheckoutContainer.style.display = 'block';
                finalCheckoutContainer.style.opacity = '0.5';
                finalCheckoutContainer.style.pointerEvents = 'none';
            } else {
                console.log('✅ Checkout button visibility confirmed');
            }
        } else {
            console.log('❌ Checkout button container not found after reset');
        }
    }, 100);
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
    if (!paymentMethodSelect) return; // Exit if element doesn't exist on this page

    var selectedPaymentMethod = paymentMethodSelect.value;

    var cashFields = document.getElementById("cash_fields");
    var mpesaFields = document.getElementById("mpesa_fields");
    var mpesaOnlineFields = document.getElementById("mpesa_online_fields");

    if (selectedPaymentMethod === "cash") {
        if (cashFields) cashFields.style.display = "block";
        if (mpesaFields) mpesaFields.style.display = "none";
        if (mpesaOnlineFields) mpesaOnlineFields.style.display = "none";
    } else if (selectedPaymentMethod === "mpesa") {
        if (cashFields) cashFields.style.display = "none";
        if (mpesaFields) mpesaFields.style.display = "block";
        if (mpesaOnlineFields) mpesaOnlineFields.style.display = "none";
    } else if (selectedPaymentMethod === "mpesa_online") {
        if (cashFields) cashFields.style.display = "none";
        if (mpesaFields) mpesaFields.style.display = "none";
        if (mpesaOnlineFields) mpesaOnlineFields.style.display = "block";

        // Fetch pending payments when M-Pesa Online is selected
        fetchPendingPayments();
    }
}


// Enhanced Payment Method Selection Functions
function selectPaymentMethod(paymentType) {
    console.log('Selecting payment method:', paymentType);

    // Update button states
    const buttons = ['cash_btn', 'mpesa_btn', 'mpesa_online_btn'];
    buttons.forEach(btnId => {
        const btn = document.getElementById(btnId);
        if (btn) {
            if (btnId === paymentType + '_btn') {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        }
    });

    // Hide all payment fields first
    const fieldContainers = ['cash_fields', 'mpesa_fields', 'mpesa_online_fields'];
    fieldContainers.forEach(containerId => {
        const container = document.getElementById(containerId);
        if (container) {
            container.style.display = 'none';
        }
    });

    // Show selected payment fields
    const selectedContainer = document.getElementById(paymentType + '_fields');
    if (selectedContainer) {
        selectedContainer.style.display = 'block';
    }

    // Special handling for M-Pesa Online
    if (paymentType === 'mpesa_online') {
        fetchPendingPayments();
    }

    // Update hidden payment method field for form submission
    const paymentMethodField = document.getElementById('payment_method');
    if (paymentMethodField) {
        paymentMethodField.value = paymentType;
    }

    // Focus appropriate input field
    setTimeout(() => {
        if (paymentType === 'cash') {
            const cashInput = document.getElementById('checkout_payment_input');
            if (cashInput) cashInput.focus();
        } else if (paymentType === 'mpesa') {
            const mpesaInput = document.getElementById('mpesa_payment_input');
            if (mpesaInput) mpesaInput.focus();
        }
    }, 100);
}

function onPaymentSelectionChange() {
    handlePaymentSelection({ target: document.getElementById('pending_payments_select') });
}

// Helper functions for checkout button state management
function enableCheckoutButton() {
    const checkoutContainer = document.getElementById('checkout_button_container');
    const checkoutButton = checkoutContainer ? checkoutContainer.querySelector('.product_type') : null;
    const hintText = checkoutContainer ? checkoutContainer.querySelector('p') : null;

    if (checkoutContainer) {
        checkoutContainer.style.opacity = '1';
        checkoutContainer.style.pointerEvents = 'auto';
    }

    if (checkoutButton) {
        checkoutButton.style.backgroundColor = '#182A62';
        checkoutButton.style.cursor = 'pointer';
    }

    if (hintText) {
        hintText.textContent = '✅ Ready to checkout!';
        hintText.style.color = '#28a745';
    }

    console.log('✅ Checkout button enabled');
}

function disableCheckoutButton() {
    const checkoutContainer = document.getElementById('checkout_button_container');
    const checkoutButton = checkoutContainer ? checkoutContainer.querySelector('.product_type') : null;
    const hintText = checkoutContainer ? checkoutContainer.querySelector('p') : null;

    if (checkoutContainer) {
        checkoutContainer.style.opacity = '0.5';
        checkoutContainer.style.pointerEvents = 'none';
    }

    if (checkoutButton) {
        checkoutButton.style.backgroundColor = '#ccc';
        checkoutButton.style.cursor = 'not-allowed';
    }

    if (hintText) {
        hintText.textContent = '💡 Add payment details first';
        hintText.style.color = '#666';
    }

    console.log('❌ Checkout button disabled');
}

// Call togglePaymentFields initially to show/hide fields based on default selection (only if elements exist)
if (document.getElementById("payment_method")) {
    // Initialize with cash payment method selected by default
    selectPaymentMethod('cash');
}



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
    // Get the recording user
    var recordingUserInput = document.getElementById('recording_user');
    var recordingUser = recordingUserInput ? recordingUserInput.value : '';

    // Determine selected payment method from button states
    var selectedPaymentMethod = null;
    var input_value = null;
    var selectedPaymentData = null;

    // Check which payment method button is active
    if (document.getElementById('cash_btn').classList.contains('active')) {
        selectedPaymentMethod = "cash";
        var paymentInput = document.getElementById("checkout_payment_input");
        input_value = paymentInput ? paymentInput.value : null;
    } else if (document.getElementById('mpesa_btn').classList.contains('active')) {
        selectedPaymentMethod = "mpesa";
        var mpesaPaymentInput = document.getElementById("mpesa_payment_input");
        input_value = mpesaPaymentInput ? mpesaPaymentInput.value : null;
    } else if (document.getElementById('mpesa_online_btn').classList.contains('active')) {
        selectedPaymentMethod = "mpesa_online";
        var pendingPaymentsSelect = document.getElementById("pending_payments_select");

        if (!pendingPaymentsSelect || !pendingPaymentsSelect.value) {
            flash_message("❌ Please select a pending payment first");
            return;
        }

        const selectedOption = pendingPaymentsSelect.options[pendingPaymentsSelect.selectedIndex];
        selectedPaymentData = {
            id: pendingPaymentsSelect.value,
            amount: parseFloat(selectedOption.dataset.amount || 0),
            sender: selectedOption.dataset.sender || 'Unknown',
            reference: selectedOption.dataset.reference || 'N/A'
        };
        input_value = selectedPaymentData.amount;
    }

    // Validate payment method selection
    if (!selectedPaymentMethod) {
        flash_message("❌ Please select a payment method first");
        return;
    }

    // Validate input value
    if (!input_value || input_value === '') {
        flash_message("❌ Please enter a payment amount");
        return;
    }

    input_value = Number(input_value);

    if (isNaN(input_value) || input_value <= 0) {
        flash_message("❌ Please enter a valid payment amount");
        return;
    }

    console.log("update_payment!");
    console.log("Recording User:", recordingUser);
    console.log("Selected Payment Method:", selectedPaymentMethod);
    console.log("Payment Input Value:", input_value);
    console.log("M-Pesa Online Selected Payment:", selectedPaymentData);

    // Get additional form elements for M-Pesa
    var mpesaGatewaySelect = document.getElementById("mpesa_gateway");
    var mpesaReferenceInput = document.getElementById("mpesa_reference_input");

    set_payment(recordingUser, input_value, selectedPaymentMethod, mpesaGatewaySelect, mpesaReferenceInput, selectedPaymentData);
}





function set_payment(recordingUser, input, selectedPaymentMethod, mpesaGatewaySelect, mpesaReferenceInput, selectedPaymentData = null) {
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

            // Enable checkout button
            enableCheckoutButton();

            get_change();
        } else {
            document.getElementById("input_error").style.display = "block";
            document.getElementById("input_error").innerHTML = "Payment is not enough";

            // Disable checkout button
            disableCheckoutButton();
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

        // Enable checkout button
        enableCheckoutButton();

        get_change();
    } else if (selectedPaymentMethod === "mpesa_online") {
        if (!recordingUser || !selectedPaymentData) {
            console.log("Empty arguments detected for M-Pesa Online");
            return;
        }

        console.log("Processing M-Pesa Online payment with selected payment data:", selectedPaymentData);

        // For M-Pesa Online, validation is done when selecting the payment
        // The amount is already validated in the frontend when selecting the payment
        sale_object.sale_clerk = recordingUser;
        sale_object.sale_payment = input; // This is the reconciled payment amount
        sale_object.payment_method = "MPESA_ONLINE"; // Update payment method
        sale_object.payment_reference = `PAYMENT_ID:${selectedPaymentData.id}`; // Store payment ID for backend reconciliation
        sale_object.payment_gateway = "MPESA_ONLINE"; // Update payment gateway
        sale_object.selected_payment_data = selectedPaymentData; // Store for backend use

        console.log("M-Pesa Online sale payment object:", sale_object);
        localStorage.setItem("current_items_pack", JSON.stringify(sale_object));

        // Enable checkout button
        enableCheckoutButton();

        get_change();
    }
}





function get_change() {
    let sale_object = JSON.parse(localStorage.getItem("current_items_pack"));
    let sale_change = sale_object.sale_payment - sale_object.sale_total;

    // Update payment summary display
    const totalElement = document.getElementById("sale_total_display2");
    const paymentElement = document.getElementById("sale_payment");
    const changeElement = document.getElementById("sale_change_display");

    if (totalElement) {
        totalElement.innerHTML = `<b>KES ${sale_object.sale_total.toFixed(2)}</b>`;
    }

    if (paymentElement) {
        paymentElement.innerHTML = `<b>KES ${sale_object.sale_payment.toFixed(2)}</b>`;
    }

    if (changeElement) {
        if (sale_change >= 0) {
            changeElement.innerHTML = `<b>KES ${sale_change.toFixed(2)}</b>`;
        } else {
            changeElement.innerHTML = "<b>KES 0.00</b>";
        }
    }

    // Update receipt template values for printing
    document.getElementById("cash_row").innerHTML = `Cash : ${sale_object.sale_payment.toFixed(2)}`;
    document.getElementById("change_row").innerHTML = `Change : ${Math.abs(sale_change).toFixed(2)}`;

    sale_object.sale_change = sale_change;
    localStorage.setItem("current_items_pack", JSON.stringify(sale_object));

    // Hide error messages when payment is valid
    const errorElement = document.getElementById("input_error");
    if (errorElement) {
        errorElement.style.display = "none";
    }

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

    // SPECIAL HANDLING FOR M-PESA ONLINE: Perform reconciliation before sale
    if (sale_object.payment_method === 'MPESA_ONLINE' && sale_object.selected_payment_data) {
        console.log('M-Pesa Online payment detected - performing reconciliation first');

        // Extract payment ID from reference
        const paymentIdMatch = sale_object.payment_reference.match(/PAYMENT_ID:(\d+)/);
        if (!paymentIdMatch) {
            flash_message('❌ Invalid M-Pesa Online payment reference');
            return;
        }

        const paymentId = paymentIdMatch[1];

        // Call reconciliation API
        const reconcilePayload = {
            payment_id: paymentId,
            sale_total: sale_object.sale_total
        };

        console.log('Calling reconciliation API:', reconcilePayload);

        fetch(`${window.location.origin}/reconcile_mpesa_payment`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(reconcilePayload)
        })
        .then(resp => resp.json())
        .then(reconcileData => {
            console.log('Reconciliation response:', reconcileData);

        if (reconcileData.status === 'reconciliation_success') {
            console.log('✅ Reconciliation successful - proceeding with sale');
            // Store reconciliation success to prevent duplicate attempts
            sale_object.reconciliation_completed = true;
            sale_object.reconciled_payment_id = reconcileData.payment_id;
            sale_object.reconciled_amount = reconcileData.reconciled_amount;
            sale_object.change_amount = reconcileData.change_amount;
            localStorage.setItem('current_items_pack', JSON.stringify(sale_object));

            // Proceed with sale after successful reconciliation
            proceedWithSale(current_sale_clerk, sale_object);
        } else if (reconcileData.status === 'reconciliation_failed') {
            console.log('❌ Reconciliation failed:', reconcileData.message);
            flash_message(`❌ Payment reconciliation failed: ${reconcileData.message}`);
            return;
        } else {
            console.log('❌ Reconciliation error:', reconcileData.message);
            flash_message(`❌ Reconciliation error: ${reconcileData.message || 'Unknown error'}`);
            return;
        }
        })
        .catch(error => {
            console.log('Reconciliation API error:', error);
            flash_message('❌ Failed to reconcile payment. Please try again.');
        });

        return; // Exit here for M-Pesa Online - proceedWithSale will be called on success
    }

    // For non-M-Pesa Online payments, proceed directly
    proceedWithSale(current_sale_clerk, sale_object);
}

function proceedWithSale(current_sale_clerk, sale_object) {
    console.log('Proceeding with sale after reconciliation (if needed)');

    // Adjust timestamp for backend time sync (backend is 2 hours behind)
    const now = new Date();
    now.setHours(now.getHours() + 2); // Add 2 hours for backend sync
    sale_object.timestamp = now.toISOString();

    console.log('Adjusted timestamp for backend:', sale_object.timestamp);

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
        if (data.status === false || data.status === 'failed') {
            console.log('Sale record addition failed');
            // Display error message to user
            const errorMessage = data.error || 'Sale failed due to unknown error';
            flash_message(`❌ Sale Failed: ${errorMessage}`);
            return;
        } else {
            console.log('Sale record added successfully');
            // Store the sale_id for receipt display and PDF download
            if (data.sale_record && data.sale_record.id) {
                const saleId = data.sale_record.id;
                localStorage.setItem('last_sale_id', saleId);

                // Open final receipt (with payment info) in a new window immediately after checkout - ONLY SHOW RECEIPT
                setTimeout(() => {
                    const currentOrigin = window.location.origin;
                    const finalReceiptUrl = `${currentOrigin}/download-sale-receipt/${saleId}?format=print&t=${Date.now()}`;

                    try {
                        const receiptWindow = window.open(finalReceiptUrl, '_blank', 'width=400,height=600,scrollbars=yes,resizable=yes');
                        if (receiptWindow) {
                            console.log(`EXPLICIT: Final receipt opened in new window for sale ID: ${saleId} - NO PRINT BUTTONS SHOWN`);
                            localStorage.setItem('receipt_window_open', 'true');

                            // Monitor if window is closed and reset interface for new sale
                            const checkClosed = setInterval(() => {
                                if (receiptWindow.closed) {
                                    clearInterval(checkClosed);
                                    localStorage.removeItem('receipt_window_open');

                                    // Reset to initial sales state when receipt window is closed
                                    console.log('Receipt window closed - resetting to initial sales state');
                                    reset_app();

                                    // Reset interface elements
                                    const checkoutContainer = document.getElementById('checkout_container');
                                    if (checkoutContainer) {
                                        checkoutContainer.style.display = 'none';
                                    }

                                    const saleContainer = document.getElementById('sale_container');
                                    if (saleContainer) {
                                        saleContainer.style.display = 'block';
                                    }

                                    // Clear iframe
                                    const iframe = document.getElementById('receipt_pdf_viewer');
                                    if (iframe) {
                                        iframe.src = 'about:blank';
                                    }

                                    // Reset viewer description
                                    const viewerContainer = document.getElementById('pdf_viewer_container');
                                    if (viewerContainer) {
                                        const title = viewerContainer.querySelector('h5');
                                        if (title) {
                                            title.textContent = 'Receipt Preview (58mm Thermal)';
                                        }
                                        const description = viewerContainer.querySelector('p');
                                        if (description) {
                                            description.textContent = '58mm thermal paper layout - No payment information shown';
                                        }
                                    }

                                    flash_message('🛒 Ready for new sale. Receipt window closed.');
                                    document.getElementById('code_input').focus();
                                }
                            }, 1000);

                            // Update the viewer description to indicate receipt is shown
                            const viewerContainer = document.getElementById('pdf_viewer_container');
                            if (viewerContainer) {
                                const description = viewerContainer.querySelector('p');
                                if (description) {
                                    description.textContent = 'Final Receipt displayed in new window - Sale completed successfully';
                                }
                            }
                        } else {
                            console.error("Popup blocked - loading in iframe as fallback");
                            // Fallback to iframe loading
                            const iframe = document.getElementById('receipt_pdf_viewer');
                            if (iframe) {
                                iframe.src = finalReceiptUrl;
                                const viewerContainer = document.getElementById('pdf_viewer_container');
                                if (viewerContainer) {
                                    const description = viewerContainer.querySelector('p');
                                    if (description) {
                                        description.textContent = 'Final Receipt displayed - Sale completed successfully';
                                    }
                                }
                            }
                        }
                    } catch (e) {
                        console.error("Failed to open receipt window:", e);
                        flash_message('⚠️ Could not open receipt window. Please allow popups.');
                    }
                }, 1000); // Allow database transaction to complete

                // Hide checkout elements and show post-checkout print button
                const elementsToHide = [
                    'back_button_container',
                    'checkout_sale',
                    'add_btn_container',
                    'checkout_button_container'
                ];

                elementsToHide.forEach(id => {
                    const element = document.getElementById(id);
                    if (element) {
                        element.style.display = 'none';
                    }
                });

                // Show the post-checkout print button (separate from print/cancel interface)
                const postCheckoutPrintBtn = document.getElementById('post_checkout_print_button');
                if (postCheckoutPrintBtn) {
                    postCheckoutPrintBtn.style.display = 'block';
                }

                // Flash success message
                flash_message('✅ Sale completed successfully! Final receipt displayed.');
            } else {
                console.error('Sale record added but no sale_record data returned');
                flash_message('❌ Sale completed but receipt data is missing');
            }
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

        // EXPLICITLY SHOW elements that should be visible during checkout
        // (in case they were hidden by cancel operation)
        const elementsToShow = [
            'back_button_container',
            'checkout_sale',
            'add_btn_container'
        ];

        elementsToShow.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                element.style.display = 'block';
                console.log(`Showing checkout element: ${id}`);
            }
        });

        // Generate and display PDF preview instead of HTML template
        generate_receipt_preview();

        document.getElementById('checkout_payment_input').focus()

    }
    document.getElementById('code_input').focus()

}

function generate_receipt_preview() {
    console.log('Generating receipt PDF preview...');

    // Generate transaction code for preview (same as final receipt)
    let rand_num = generateRandomNumber();
    document.getElementById('tranx_code').textContent = rand_num;

    // Generate barcode and QR code for the preview
    generateBarcode(rand_num);
    generateQRCode(rand_num);

    // Get current sale data
    const current_sale_clerk = document.getElementById('user_name_span').innerHTML;
    const sale_object = JSON.parse(localStorage.getItem('current_items_pack'));

    // Get items array for the PDF
    const items_json = JSON.stringify(sale_object.item_array);

    // Create PDF preview URL with all necessary data
    const previewUrl = `${window.location.origin}/preview-sale-receipt?format=pdf&clerk=${encodeURIComponent(current_sale_clerk)}&total=${sale_object.sale_total}&transaction_code=${rand_num}&items=${encodeURIComponent(items_json)}`;

    // Load PDF into iframe
    const iframe = document.getElementById('receipt_pdf_viewer');
    iframe.src = previewUrl;

    console.log('Receipt PDF preview generated:', previewUrl);
    console.log('Items being sent to PDF:', sale_object.item_array);
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



function trigger_print_dialogue() {
    console.log("EXPLICIT: Triggering print for receipt in dedicated window");

    const saleId = localStorage.getItem('last_sale_id');
    if (!saleId) {
        console.error("No sale ID found for receipt printing");
        flash_message("Error: No sale record found for printing");
        return;
    }

    const currentOrigin = window.location.origin;
    const finalReceiptUrl = `${currentOrigin}/download-sale-receipt/${saleId}?format=print&t=${Date.now()}`;

    try {
        // Check if receipt window is already open
        const isWindowOpen = localStorage.getItem('receipt_window_open') === 'true';

        if (isWindowOpen) {
            // Try to focus existing window or check if it's still open
            // Since we can't directly access the window object, we'll open a new one
            console.log("Receipt window should be open, opening new print window");
        }

        // Open fresh PDF window for printing
        const printWindow = window.open(finalReceiptUrl, '_blank', 'width=400,height=600,scrollbars=yes,resizable=yes');

        if (printWindow) {
            // Wait for PDF to load, then trigger print
            printWindow.onload = function() {
                setTimeout(() => {
                    try {
                        printWindow.print();
                        console.log("Print dialogue opened in dedicated PDF window");
                        flash_message('🖨️ Print dialogue opened in receipt window.');
                    } catch (e) {
                        console.log("Print trigger failed:", e);
                        flash_message('❌ Could not open print dialogue. Please use Ctrl+P in the receipt window.');
                    }
                }, 500); // Wait for PDF to fully render
            };

            printWindow.onerror = function() {
                console.error("Failed to load PDF in print window");
                flash_message('❌ Failed to load receipt PDF. Please try again.');
            };
        } else {
            console.error("Popup blocked for print window");
            flash_message('⚠️ Popup blocked. Please allow popups and try again.');
        }
    } catch (e) {
        console.error("Failed to open print window:", e);
        flash_message('❌ Could not open print window. Please use Ctrl+P on the receipt.');
    }
}

function cancel_print_and_clear() {
    console.log("Cancelling print operation - COMPLETE RESET to clean initial state");

    // FULL RESET: Clear all data and reset to initial sales state
    reset_app();

    // EXPLICITLY reset ALL interface elements to clean initial state
    // Hide checkout container and all its contents
    const checkoutContainer = document.getElementById('checkout_container');
    if (checkoutContainer) {
        checkoutContainer.style.display = 'none';

        // Explicitly hide all elements within checkout container
        const allCheckoutElements = checkoutContainer.querySelectorAll('*');
        allCheckoutElements.forEach(element => {
            if (element.id) {
                element.style.display = 'none';
            }
        });
    }

    // Show sale container
    const saleContainer = document.getElementById('sale_container');
    if (saleContainer) {
        saleContainer.style.display = 'block';
    }

    // DOUBLE-CHECK: Explicitly hide any print-related elements that might still be visible
    // NOTE: checkout_button_container is intentionally NOT hidden here because reset_app() will make it visible again
    const elementsToForceHide = [
        'post_checkout_print_button',
        'print_button_container',
        'back_button_container',
        'checkout_sale',
        'add_btn_container'
    ];

    elementsToForceHide.forEach(id => {
        const element = document.getElementById(id);
        if (element) {
            element.style.display = 'none';
            console.log(`Force hiding element: ${id}`);
        }
    });

    // Clear the iframe completely
    const iframe = document.getElementById('receipt_pdf_viewer');
    if (iframe) {
        iframe.src = 'about:blank'; // More thorough clearing
        console.log('Iframe cleared to about:blank');
    }

    // Reset the viewer description back to preview mode
    const viewerContainer = document.getElementById('pdf_viewer_container');
    if (viewerContainer) {
        const title = viewerContainer.querySelector('h5');
        if (title) {
            title.textContent = 'Receipt Preview (58mm Thermal)';
        }
        const description = viewerContainer.querySelector('p');
        if (description) {
            description.textContent = '58mm thermal paper layout - No payment information shown';
        }
        console.log('Viewer description reset to preview mode');
    }

    // Final cleanup: Ensure no stray elements are visible
    setTimeout(() => {
        console.log('Final cleanup check after cancel');
        // Any additional cleanup if needed
    }, 100);

    flash_message('❌ Print cancelled. Complete reset to initial sales state.');
    document.getElementById('code_input').focus();
}

function show_print_interface() {
    console.log("Showing print interface with print/cancel buttons");

    // Hide the post-checkout print button
    const postCheckoutPrintBtn = document.getElementById('post_checkout_print_button');
    if (postCheckoutPrintBtn) {
        postCheckoutPrintBtn.style.display = 'none';
    }

    // Show the print/cancel interface
    const printButtonContainer = document.getElementById('print_button_container');
    if (printButtonContainer) {
        printButtonContainer.style.display = 'block';
    }

    flash_message('🖨️ Print interface activated. Click Print to print receipt.');
}

function fetchPendingPayments() {
    console.log("Fetching pending payments for M-Pesa Online reconciliation...");

    const url = `${window.location.origin}/get_pending_payments`;

    fetch(url)
    .then(response => response.json())
    .then(data => {
        console.log("Pending payments response:", data);

        const selectElement = document.getElementById('pending_payments_select');
        if (!selectElement) {
            console.error("Pending payments select element not found");
            return;
        }

        // Clear existing options except the first one
        selectElement.innerHTML = '<option value="">Select a pending payment...</option>';

        if (data.status === 'success' && data.payments && data.payments.length > 0) {
            data.payments.forEach(payment => {
                const option = document.createElement('option');
                option.value = payment.id;
                option.textContent = payment.display_text;
                option.dataset.amount = payment.amount;
                option.dataset.sender = payment.sender || 'Unknown';
                option.dataset.reference = payment.reference || 'N/A';
                option.dataset.date = payment.display_datetime;
                selectElement.appendChild(option);
            });

            console.log(`Loaded ${data.payments.length} pending payments`);
            flash_message(`📊 Found ${data.payments.length} pending payments for reconciliation`);

            // Add change event listener to handle payment selection
            selectElement.addEventListener('change', handlePaymentSelection);
        } else {
            const option = document.createElement('option');
            option.value = "";
            option.textContent = "No pending payments available";
            selectElement.appendChild(option);
            console.log("No pending payments found");
            flash_message("⚠️ No pending payments available for reconciliation");
        }
    })
    .catch(error => {
        console.error("Error fetching pending payments:", error);
        const selectElement = document.getElementById('pending_payments_select');
        if (selectElement) {
            selectElement.innerHTML = '<option value="">Error loading payments</option>';
        }
        flash_message("❌ Failed to load pending payments");
    });
}

function handlePaymentSelection(event) {
    const selectElement = event.target;
    const selectedOption = selectElement.options[selectElement.selectedIndex];

    const paymentId = selectedOption.value;
    const amount = selectedOption.dataset.amount;
    const sender = selectedOption.dataset.sender;
    const reference = selectedOption.dataset.reference;
    const date = selectedOption.dataset.date;

    console.log(`Payment selected: ID=${paymentId}, Amount=${amount}, Sender=${sender}`);

    const infoDiv = document.getElementById('selected_payment_info');
    const statusElement = document.getElementById('reconciliation_status');

    if (paymentId && amount) {
        // Show payment details
        document.getElementById('selected_payment_amount').textContent = `Amount: KES ${parseFloat(amount).toFixed(2)}`;
        document.getElementById('selected_payment_sender').textContent = `Sender: ${sender}`;
        document.getElementById('selected_payment_reference').textContent = `Reference: ${reference}`;
        document.getElementById('selected_payment_date').textContent = `Date: ${date}`;

        infoDiv.style.display = 'block';

        // Get current sale total for comparison
        const saleObject = JSON.parse(localStorage.getItem('current_items_pack'));
        const saleTotal = saleObject ? saleObject.sale_total : 0;

        console.log(`Sale total: ${saleTotal}, Payment amount: ${amount}`);

        if (parseFloat(amount) >= saleTotal) {
            const change = parseFloat(amount) - saleTotal;
            if (change > 0) {
                statusElement.textContent = `✅ Payment accepted! Change: KES ${change.toFixed(2)}`;
                statusElement.style.color = "green";
            } else {
                statusElement.textContent = "✅ Amount matches exactly! Ready for reconciliation.";
                statusElement.style.color = "green";
            }
            statusElement.style.fontWeight = "bold";
        } else {
            statusElement.textContent = `❌ Insufficient payment! Payment: KES ${parseFloat(amount).toFixed(2)}, Required: KES ${saleTotal.toFixed(2)}`;
            statusElement.style.color = "red";
            statusElement.style.fontWeight = "bold";
        }
    } else {
        // Hide payment details when nothing is selected
        infoDiv.style.display = 'none';
        statusElement.textContent = "";
    }
}

function download_sale_receipt() {
    // Legacy function - kept for compatibility but now uses trigger_print_dialogue
    trigger_print_dialogue();
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
