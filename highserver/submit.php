<?php
function sanitize($name){
  return preg_replace('/[^A-Za-z0-9\-_ ]/', '', $name);
}

function cmp($a, $b){
  return $b->score - $a->score;
}

if (isset($_GET['username']) && isset($_GET['score']) && is_numeric($_GET['score']) && isset($_GET['magic']) && is_numeric($_GET['magic'])) {
  $username = $_GET['username'];
  $score = intval($_GET['score']);
  $magic = intval($_GET['magic']);
  if ($magic == ($score % 17 * strlen($username) + floor($score / 17))){
    if (!file_exists("highscore.txt")){
      file_put_contents("highscore.txt", "[]");
    }
    $highfile = file_get_contents("highscore.txt");
    $high = json_decode($highfile);
    $high[] = (object) array(name => sanitize($username), score => $score);
    usort($high, "cmp");
    while(count($high) > 10){
      unset($high[10]);
    }
    file_put_contents("highscore.txt", json_encode($high));
    echo "Thx";
  }
}
?>
