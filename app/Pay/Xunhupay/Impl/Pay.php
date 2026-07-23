<?php
declare(strict_types=1);

namespace App\Pay\Xunhupay\Impl;

use App\Entity\PayEntity;
use App\Pay\Base;
use App\Util\Http;
use App\Util\Str;
use GuzzleHttp\Exception\GuzzleException;
use Kernel\Exception\JSONException;

/**
 * Class Pay
 * @package App\Pay\Kvmpay\Impl
 */
class Pay extends Base implements \App\Pay\Pay
{

    /**
     * @return PayEntity
     * @throws JSONException|GuzzleException
     */
    public function trade(): PayEntity
    {

        $appid = $this->config["c{$this->code}_appId"];
        $hashKey = $this->config["c{$this->code}_key"];
        $url = $this->config["c{$this->code}_url"];

        $param = [
            'version' => '1.1',
            'appid' => $appid,
            'trade_order_id' => $this->tradeNo,
            'total_fee' => $this->amount,
            'title' => $this->tradeNo,
            'time' => time(),
            'attach' => $this->code,
            'notify_url' => $this->callbackUrl,
            'return_url' => $this->returnUrl,
            'callback_url' => $this->returnUrl,
            'nonce_str' => Str::generateRandStr(),
        ];
        if(Signature::isMobile()){
          $param['type'] = "WAP";
          $param['wap_url'] = $this->config['domain'];
          $param['wap_name'] = $this->config['shop_name'];
        }
        $param['hash'] = Signature::generateSignature($param, $hashKey);

        try {
            $request = Http::make()->post($url, [
                "form_params" => $param
            ]);

            $contents = $request->getBody()->getContents();
            $json = json_decode($contents, true);
            if ($json['errcode'] != 0) {
                throw new JSONException((string)$json['errmsg']);
            }
            $url = $json['url'];
        } catch (\Exception|\Error $e) {
            throw new JSONException("请求失败");
        }

        $payEntity = new PayEntity();
        if(Signature::isMobile()){
          $payEntity->setType(self::TYPE_REDIRECT);
          $payEntity->setUrl($url);
        }else{
          $payEntity->setType(self::TYPE_LOCAL_RENDER);
          $payEntity->setUrl($json['url_qrcode']);
        }
        return $payEntity;
    }
}