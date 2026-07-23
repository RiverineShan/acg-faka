<?php
declare (strict_types=1);

return [
    'version' => '1.0.0',
    'name' => '虎皮椒',
    'author' => '荔枝',
    'website' => '#',
    'description' => '支持基于[虎皮椒]协议的支付平台',
    'options' => [
        1 => '支付宝个人V1.0',
        2 => '官方微信个人H5支付',
        3 => '官方微信个人支付'
    ],
    'callback' => [
        \App\Consts\Pay::IS_SIGN => true,
        \App\Consts\Pay::IS_STATUS => true,
        \App\Consts\Pay::FIELD_STATUS_KEY => 'status',
        \App\Consts\Pay::FIELD_STATUS_VALUE => 'OD',
        \App\Consts\Pay::FIELD_ORDER_KEY => 'trade_order_id',
        \App\Consts\Pay::FIELD_AMOUNT_KEY => 'total_fee',
        \App\Consts\Pay::FIELD_RESPONSE => 'success'
    ]
];