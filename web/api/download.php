<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: https://door-fujita.com');

$countFile = __DIR__ . '/download_count.json';

if (!file_exists($countFile)) {
    file_put_contents($countFile, json_encode([
        'zip' => 0,
        'ahk' => 0,
        'total' => 0,
        'log' => []
    ]));
}

$data = json_decode(file_get_contents($countFile), true);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $type = isset($input['type']) ? $input['type'] : 'unknown';

    if (in_array($type, ['zip', 'ahk'])) {
        $data[$type]++;
        $data['total']++;
        $data['log'][] = [
            'type' => $type,
            'date' => date('Y-m-d H:i:s'),
            'ip' => substr(hash('sha256', $_SERVER['REMOTE_ADDR']), 0, 8)
        ];
        // Keep only last 500 log entries
        if (count($data['log']) > 500) {
            $data['log'] = array_slice($data['log'], -500);
        }
        file_put_contents($countFile, json_encode($data, JSON_PRETTY_PRINT));
    }

    echo json_encode(['ok' => true, 'total' => $data['total']]);
} else {
    echo json_encode([
        'zip' => $data['zip'],
        'ahk' => $data['ahk'],
        'total' => $data['total']
    ]);
}
