<?php
declare(strict_types=1);

namespace App\Pay\Xunhupay\Impl;

use App\Util\Client;

class Signature implements \App\Pay\Signature
{
    /**
     * @param array $data
     * @param string $hashKey
     * @return string
     */
    public static function generateSignature(array $data, string $hashKey): string
    {
        ksort($data);
        reset($data);
        $arg = '';
        foreach ($data as $key => $val) {
            if ($key == 'hash' || is_null($val) || $val === '') {
                continue;
            }
            if ($arg) {
                $arg .= '&';
            }
            $arg .= "{$key}={$val}";
        }
        return md5($arg . $hashKey);
    }

    /**
     * @inheritDoc
     */
    public function verification(array $data, array $config): bool
    {
        $sign = $data['hash'];
        unset($data['hash']);
        $hashKey = $config["c{$data['attach']}_key"];
        $generateSignature = self::generateSignature($data, $hashKey);
        if ($sign != $generateSignature) {
            return false;
        }
        return true;
    }

    public static function isMobile(): bool
    {
        $clientHint = trim((string)($_SERVER['HTTP_SEC_CH_UA_MOBILE'] ?? ''));
        if ($clientHint === '?0') {
            return false;
        }
        if ($clientHint === '?1') {
            return true;
        }

        return Client::getDeviceTypeByUa() !== 0;
    }
}
