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
        $url = trim((string)($this->config["c{$this->code}_url"] ?? ''));
        if (filter_var($url, FILTER_VALIDATE_URL) === false) {
            $url = 'https://api.xunhupay.com/payment/do.html';
        }

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
        $forceDesktopQr = (string)$this->code === '1';
        if(!$forceDesktopQr && Signature::isMobile()){
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
            if (!is_array($json)) {
                throw new JSONException("支付网关返回的数据格式无效");
            }
            if ((int)($json['errcode'] ?? -1) !== 0) {
                throw new JSONException((string)($json['errmsg'] ?? '支付网关返回未知错误'));
            }
            if (empty($json['url'])) {
                throw new JSONException("支付网关未返回付款地址");
            }
            $url = $json['url'];
        } catch (JSONException $e) {
            $this->log("Xunhupay: {$e->getMessage()}");
            throw $e;
        } catch (\Throwable $e) {
            $this->log("Xunhupay connection error: {$e->getMessage()}");
            throw new JSONException("支付网关连接失败");
        }

        $payEntity = new PayEntity();
        if(!$forceDesktopQr && Signature::isMobile()){
          $payEntity->setType(self::TYPE_REDIRECT);
          $payEntity->setUrl($url);
        }else{
          $payEntity->setType(self::TYPE_LOCAL_RENDER);
          $payEntity->setUrl($json['url_qrcode'] ?? $url);
        }
        return $payEntity;
    }
}
