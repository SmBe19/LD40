<?php
if (!file_exists("highscore.txt")){
  file_put_contents("highscore.txt", "[]");
}
$high = file_get_contents("highscore.txt");
if (isset($_GET['format'])){
  if ($_GET['format'] == "lua") {
    $highjs = json_decode($high);
    for($i = 0; $i < count($highjs); $i++){
      echo $highjs[$i]->name;
      echo "\n";
      echo $highjs[$i]->score;
      echo "\n";
    }
  } else {
    echo $high;
    echo "\n";
  }
} else {
  echo $high;
  echo "\n";
}
?>
