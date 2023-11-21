
function SubmitCategories() {
  var checkedBoxes = getCheckedBoxes("doodlecategory");
  var allString = checkedBoxes.map(function(i) {return i.value;}).join('£');  
  document.doodlecategories.doodlecategories.value = allString;
}


// Pass the checkbox name to the function
function getCheckedBoxes(chkboxName) {
  var checkboxes = document.getElementsByName(chkboxName);
  var checkboxesChecked = [];
  // loop over them all
  for (var i=0; i<checkboxes.length; i++) {
     // And stick the checked ones onto an array...
     if (checkboxes[i].checked) {
        checkboxesChecked.push(checkboxes[i]);
     }
  }
  // Return the array if it is non-empty, or null
  return checkboxesChecked.length > 0 ? checkboxesChecked : null;
}

    
function deselectAll() {
    var checkboxes = document.getElementsByName('doodlecategory');
  for (var i=0; i<checkboxes.length; i++) {
     if (checkboxes[i].checked) {
        checkboxes[i].checked = false;
     }
  }
}