export function _summary(input) {
  let acc3280 = 0.0;
  let t3281 = input["fed"];
  let t3282 = t3281["single"];
  let t3283 = t3282["rates"];
  let acc3349 = 0.0;
  let t3301 = input["income"];
  let t3302 = input["fed"];
  const t3306 = 0;
  const t3325 = -1;
  const t3327 = 100000000000.0;
  let t3303 = t3302["single"];
  let t3304 = t3303["std"];
  let t3305 = t3301 - t3304;
  let t3307 = [t3305, t3306];
  let t3308 = Math.max(...t3307);
  t3283.forEach((t3284, t3285) => {
    let t3320 = t3284["lo"];
    let t3333 = t3284["hi"];
    let t3341 = t3284["rate"];
    let t3326 = t3333 == t3325;
    let t3329 = t3326 ? t3327 : t3333;
    let t3297 = t3308 >= t3320;
    let t3299 = t3308 < t3329;
    let t3300 = t3297 && t3299;
    let t3289 = t3300 ? t3341 : t3306;
    acc3280 += t3289;
    let t3364 = t3308 - t3320;
    let t3368 = t3329 - t3320;
    let t3369 = Math.min(Math.max(t3364, t3306), t3368);
    let t3357 = t3369 * t3341;
    acc3349 += t3357;
  });
  const t3344 = 1.0;
  let t3345 = [t3301, t3344];
  let t3346 = Math.max(...t3345);
  let t3347 = acc3349 / t3346;
  let acc3408 = 0.0;
  t3283.forEach((t3412, t3413) => {
    let t3440 = t3412["lo"];
    let t3453 = t3412["hi"];
    let t3465 = t3412["rate"];
    let t3423 = t3308 - t3440;
    let t3446 = t3453 == t3325;
    let t3449 = t3446 ? t3327 : t3453;
    let t3427 = t3449 - t3440;
    let t3428 = Math.min(Math.max(t3423, t3306), t3427);
    let t3416 = t3428 * t3465;
    acc3408 += t3416;
  });
  let t542 = {
    "marginal": acc3280,
    "effective": t3347,
    "tax": acc3408
  };
  const t3478 = 168600.0;
  let t3479 = [t3301, t3478];
  let t3480 = Math.min(...t3479);
  const t3481 = 0.062;
  let t3482 = t3480 * t3481;
  const t3484 = 0.0145;
  let t3485 = t3301 * t3484;
  let t3474 = t3482 + t3485;
  const t3487 = 200000.0;
  let t3488 = t3301 - t3487;
  let t3490 = [t3488, t3306];
  let t3491 = Math.max(...t3490);
  const t3492 = 0.009;
  let t3493 = t3491 * t3492;
  let t3476 = t3474 + t3493;
  let t3471 = t3476 / t3346;
  let t545 = {
    "effective": t3471,
    "tax": t3476
  };
  let t546 = input["state_rate"];
  let t3518 = t3301 * t546;
  let t549 = {
    "marginal": t546,
    "effective": t546,
    "tax": t3518
  };
  let t550 = input["local_rate"];
  let t3521 = t3301 * t550;
  let t553 = {
    "marginal": t550,
    "effective": t550,
    "tax": t3521
  };
  let acc3536 = 0.0;
  t3283.forEach((t3540, t3541) => {
    let t3568 = t3540["lo"];
    let t3581 = t3540["hi"];
    let t3593 = t3540["rate"];
    let t3551 = t3308 - t3568;
    let t3574 = t3581 == t3325;
    let t3577 = t3574 ? t3327 : t3581;
    let t3555 = t3577 - t3568;
    let t3556 = Math.min(Math.max(t3551, t3306), t3555);
    let t3544 = t3556 * t3593;
    acc3536 += t3544;
  });
  let t3530 = acc3536 + t3476;
  let t3532 = t3530 + t3518;
  let t3534 = t3532 + t3521;
  let t3527 = t3534 / t3346;
  let acc3630 = 0.0;
  t3283.forEach((t3634, t3635) => {
    let t3662 = t3634["lo"];
    let t3675 = t3634["hi"];
    let t3687 = t3634["rate"];
    let t3645 = t3308 - t3662;
    let t3668 = t3675 == t3325;
    let t3671 = t3668 ? t3327 : t3675;
    let t3649 = t3671 - t3662;
    let t3650 = Math.min(Math.max(t3645, t3306), t3649);
    let t3638 = t3650 * t3687;
    acc3630 += t3638;
  });
  let t3624 = acc3630 + t3476;
  let t3626 = t3624 + t3518;
  let t3628 = t3626 + t3521;
  let t556 = {
    "effective": t3527,
    "tax": t3628
  };
  let acc3727 = 0.0;
  t3283.forEach((t3731, t3732) => {
    let t3759 = t3731["lo"];
    let t3772 = t3731["hi"];
    let t3784 = t3731["rate"];
    let t3742 = t3308 - t3759;
    let t3765 = t3772 == t3325;
    let t3768 = t3765 ? t3327 : t3772;
    let t3746 = t3768 - t3759;
    let t3747 = Math.min(Math.max(t3742, t3306), t3746);
    let t3735 = t3747 * t3784;
    acc3727 += t3735;
  });
  let t3721 = acc3727 + t3476;
  let t3723 = t3721 + t3518;
  let t3725 = t3723 + t3521;
  let t3718 = t3301 - t3725;
  let t558 = input["retirement_contrib"];
  let acc3827 = 0.0;
  t3283.forEach((t3831, t3832) => {
    let t3859 = t3831["lo"];
    let t3872 = t3831["hi"];
    let t3884 = t3831["rate"];
    let t3842 = t3308 - t3859;
    let t3865 = t3872 == t3325;
    let t3868 = t3865 ? t3327 : t3872;
    let t3846 = t3868 - t3859;
    let t3847 = Math.min(Math.max(t3842, t3306), t3846);
    let t3835 = t3847 * t3884;
    acc3827 += t3835;
  });
  let t3821 = acc3827 + t3476;
  let t3823 = t3821 + t3518;
  let t3825 = t3823 + t3521;
  let t3818 = t3301 - t3825;
  let t3815 = t3818 - t558;
  let t560 = {
    "federal": t542,
    "fica": t545,
    "state": t549,
    "local": t553,
    "total": t556,
    "after_tax": t3718,
    "retirement_contrib": t558,
    "take_home": t3815
  };
  let acc3914 = 0.0;
  let t3916 = t3281["married_joint"];
  let t3917 = t3916["rates"];
  let acc3983 = 0.0;
  let t3937 = t3302["married_joint"];
  let t3938 = t3937["std"];
  let t3939 = t3301 - t3938;
  let t3941 = [t3939, t3306];
  let t3942 = Math.max(...t3941);
  t3917.forEach((t3918, t3919) => {
    let t3954 = t3918["lo"];
    let t3967 = t3918["hi"];
    let t3975 = t3918["rate"];
    let t3960 = t3967 == t3325;
    let t3963 = t3960 ? t3327 : t3967;
    let t3931 = t3942 >= t3954;
    let t3933 = t3942 < t3963;
    let t3934 = t3931 && t3933;
    let t3923 = t3934 ? t3975 : t3306;
    acc3914 += t3923;
    let t3998 = t3942 - t3954;
    let t4002 = t3963 - t3954;
    let t4003 = Math.min(Math.max(t3998, t3306), t4002);
    let t3991 = t4003 * t3975;
    acc3983 += t3991;
  });
  let t3981 = acc3983 / t3346;
  let acc4042 = 0.0;
  t3917.forEach((t4046, t4047) => {
    let t4074 = t4046["lo"];
    let t4087 = t4046["hi"];
    let t4099 = t4046["rate"];
    let t4057 = t3942 - t4074;
    let t4080 = t4087 == t3325;
    let t4083 = t4080 ? t3327 : t4087;
    let t4061 = t4083 - t4074;
    let t4062 = Math.min(Math.max(t4057, t3306), t4061);
    let t4050 = t4062 * t4099;
    acc4042 += t4050;
  });
  let t564 = {
    "marginal": acc3914,
    "effective": t3981,
    "tax": acc4042
  };
  const t4123 = 250000.0;
  let t4124 = t3301 - t4123;
  let t4126 = [t4124, t3306];
  let t4127 = Math.max(...t4126);
  let t4129 = t4127 * t3492;
  let t4110 = t3474 + t4129;
  let t4105 = t4110 / t3346;
  let t567 = {
    "effective": t4105,
    "tax": t4110
  };
  let acc4174 = 0.0;
  t3917.forEach((t4178, t4179) => {
    let t4206 = t4178["lo"];
    let t4219 = t4178["hi"];
    let t4231 = t4178["rate"];
    let t4189 = t3942 - t4206;
    let t4212 = t4219 == t3325;
    let t4215 = t4212 ? t3327 : t4219;
    let t4193 = t4215 - t4206;
    let t4194 = Math.min(Math.max(t4189, t3306), t4193);
    let t4182 = t4194 * t4231;
    acc4174 += t4182;
  });
  let t4168 = acc4174 + t4110;
  let t4170 = t4168 + t3518;
  let t4172 = t4170 + t3521;
  let t4165 = t4172 / t3346;
  let acc4270 = 0.0;
  t3917.forEach((t4274, t4275) => {
    let t4302 = t4274["lo"];
    let t4315 = t4274["hi"];
    let t4327 = t4274["rate"];
    let t4285 = t3942 - t4302;
    let t4308 = t4315 == t3325;
    let t4311 = t4308 ? t3327 : t4315;
    let t4289 = t4311 - t4302;
    let t4290 = Math.min(Math.max(t4285, t3306), t4289);
    let t4278 = t4290 * t4327;
    acc4270 += t4278;
  });
  let t4264 = acc4270 + t4110;
  let t4266 = t4264 + t3518;
  let t4268 = t4266 + t3521;
  let t578 = {
    "effective": t4165,
    "tax": t4268
  };
  let acc4369 = 0.0;
  t3917.forEach((t4373, t4374) => {
    let t4401 = t4373["lo"];
    let t4414 = t4373["hi"];
    let t4426 = t4373["rate"];
    let t4384 = t3942 - t4401;
    let t4407 = t4414 == t3325;
    let t4410 = t4407 ? t3327 : t4414;
    let t4388 = t4410 - t4401;
    let t4389 = Math.min(Math.max(t4384, t3306), t4388);
    let t4377 = t4389 * t4426;
    acc4369 += t4377;
  });
  let t4363 = acc4369 + t4110;
  let t4365 = t4363 + t3518;
  let t4367 = t4365 + t3521;
  let t4360 = t3301 - t4367;
  let acc4471 = 0.0;
  t3917.forEach((t4475, t4476) => {
    let t4503 = t4475["lo"];
    let t4516 = t4475["hi"];
    let t4528 = t4475["rate"];
    let t4486 = t3942 - t4503;
    let t4509 = t4516 == t3325;
    let t4512 = t4509 ? t3327 : t4516;
    let t4490 = t4512 - t4503;
    let t4491 = Math.min(Math.max(t4486, t3306), t4490);
    let t4479 = t4491 * t4528;
    acc4471 += t4479;
  });
  let t4465 = acc4471 + t4110;
  let t4467 = t4465 + t3518;
  let t4469 = t4467 + t3521;
  let t4462 = t3301 - t4469;
  let t4459 = t4462 - t558;
  let t582 = {
    "federal": t564,
    "fica": t567,
    "state": t549,
    "local": t553,
    "total": t578,
    "after_tax": t4360,
    "retirement_contrib": t558,
    "take_home": t4459
  };
  let acc4560 = 0.0;
  let t4562 = t3281["married_separate"];
  let t4563 = t4562["rates"];
  let acc4629 = 0.0;
  let t4583 = t3302["married_separate"];
  let t4584 = t4583["std"];
  let t4585 = t3301 - t4584;
  let t4587 = [t4585, t3306];
  let t4588 = Math.max(...t4587);
  t4563.forEach((t4564, t4565) => {
    let t4600 = t4564["lo"];
    let t4613 = t4564["hi"];
    let t4621 = t4564["rate"];
    let t4606 = t4613 == t3325;
    let t4609 = t4606 ? t3327 : t4613;
    let t4577 = t4588 >= t4600;
    let t4579 = t4588 < t4609;
    let t4580 = t4577 && t4579;
    let t4569 = t4580 ? t4621 : t3306;
    acc4560 += t4569;
    let t4644 = t4588 - t4600;
    let t4648 = t4609 - t4600;
    let t4649 = Math.min(Math.max(t4644, t3306), t4648);
    let t4637 = t4649 * t4621;
    acc4629 += t4637;
  });
  let t4627 = acc4629 / t3346;
  let acc4688 = 0.0;
  t4563.forEach((t4692, t4693) => {
    let t4720 = t4692["lo"];
    let t4733 = t4692["hi"];
    let t4745 = t4692["rate"];
    let t4703 = t4588 - t4720;
    let t4726 = t4733 == t3325;
    let t4729 = t4726 ? t3327 : t4733;
    let t4707 = t4729 - t4720;
    let t4708 = Math.min(Math.max(t4703, t3306), t4707);
    let t4696 = t4708 * t4745;
    acc4688 += t4696;
  });
  let t586 = {
    "marginal": acc4560,
    "effective": t4627,
    "tax": acc4688
  };
  const t4769 = 125000.0;
  let t4770 = t3301 - t4769;
  let t4772 = [t4770, t3306];
  let t4773 = Math.max(...t4772);
  let t4775 = t4773 * t3492;
  let t4756 = t3474 + t4775;
  let t4751 = t4756 / t3346;
  let t589 = {
    "effective": t4751,
    "tax": t4756
  };
  let acc4820 = 0.0;
  t4563.forEach((t4824, t4825) => {
    let t4852 = t4824["lo"];
    let t4865 = t4824["hi"];
    let t4877 = t4824["rate"];
    let t4835 = t4588 - t4852;
    let t4858 = t4865 == t3325;
    let t4861 = t4858 ? t3327 : t4865;
    let t4839 = t4861 - t4852;
    let t4840 = Math.min(Math.max(t4835, t3306), t4839);
    let t4828 = t4840 * t4877;
    acc4820 += t4828;
  });
  let t4814 = acc4820 + t4756;
  let t4816 = t4814 + t3518;
  let t4818 = t4816 + t3521;
  let t4811 = t4818 / t3346;
  let acc4916 = 0.0;
  t4563.forEach((t4920, t4921) => {
    let t4948 = t4920["lo"];
    let t4961 = t4920["hi"];
    let t4973 = t4920["rate"];
    let t4931 = t4588 - t4948;
    let t4954 = t4961 == t3325;
    let t4957 = t4954 ? t3327 : t4961;
    let t4935 = t4957 - t4948;
    let t4936 = Math.min(Math.max(t4931, t3306), t4935);
    let t4924 = t4936 * t4973;
    acc4916 += t4924;
  });
  let t4910 = acc4916 + t4756;
  let t4912 = t4910 + t3518;
  let t4914 = t4912 + t3521;
  let t600 = {
    "effective": t4811,
    "tax": t4914
  };
  let acc5015 = 0.0;
  t4563.forEach((t5019, t5020) => {
    let t5047 = t5019["lo"];
    let t5060 = t5019["hi"];
    let t5072 = t5019["rate"];
    let t5030 = t4588 - t5047;
    let t5053 = t5060 == t3325;
    let t5056 = t5053 ? t3327 : t5060;
    let t5034 = t5056 - t5047;
    let t5035 = Math.min(Math.max(t5030, t3306), t5034);
    let t5023 = t5035 * t5072;
    acc5015 += t5023;
  });
  let t5009 = acc5015 + t4756;
  let t5011 = t5009 + t3518;
  let t5013 = t5011 + t3521;
  let t5006 = t3301 - t5013;
  let acc5117 = 0.0;
  t4563.forEach((t5121, t5122) => {
    let t5149 = t5121["lo"];
    let t5162 = t5121["hi"];
    let t5174 = t5121["rate"];
    let t5132 = t4588 - t5149;
    let t5155 = t5162 == t3325;
    let t5158 = t5155 ? t3327 : t5162;
    let t5136 = t5158 - t5149;
    let t5137 = Math.min(Math.max(t5132, t3306), t5136);
    let t5125 = t5137 * t5174;
    acc5117 += t5125;
  });
  let t5111 = acc5117 + t4756;
  let t5113 = t5111 + t3518;
  let t5115 = t5113 + t3521;
  let t5108 = t3301 - t5115;
  let t5105 = t5108 - t558;
  let t604 = {
    "federal": t586,
    "fica": t589,
    "state": t549,
    "local": t553,
    "total": t600,
    "after_tax": t5006,
    "retirement_contrib": t558,
    "take_home": t5105
  };
  let acc5206 = 0.0;
  let t5208 = t3281["head_of_household"];
  let t5209 = t5208["rates"];
  let acc5275 = 0.0;
  let t5229 = t3302["head_of_household"];
  let t5230 = t5229["std"];
  let t5231 = t3301 - t5230;
  let t5233 = [t5231, t3306];
  let t5234 = Math.max(...t5233);
  t5209.forEach((t5210, t5211) => {
    let t5246 = t5210["lo"];
    let t5259 = t5210["hi"];
    let t5267 = t5210["rate"];
    let t5252 = t5259 == t3325;
    let t5255 = t5252 ? t3327 : t5259;
    let t5223 = t5234 >= t5246;
    let t5225 = t5234 < t5255;
    let t5226 = t5223 && t5225;
    let t5215 = t5226 ? t5267 : t3306;
    acc5206 += t5215;
    let t5290 = t5234 - t5246;
    let t5294 = t5255 - t5246;
    let t5295 = Math.min(Math.max(t5290, t3306), t5294);
    let t5283 = t5295 * t5267;
    acc5275 += t5283;
  });
  let t5273 = acc5275 / t3346;
  let acc5334 = 0.0;
  t5209.forEach((t5338, t5339) => {
    let t5366 = t5338["lo"];
    let t5379 = t5338["hi"];
    let t5391 = t5338["rate"];
    let t5349 = t5234 - t5366;
    let t5372 = t5379 == t3325;
    let t5375 = t5372 ? t3327 : t5379;
    let t5353 = t5375 - t5366;
    let t5354 = Math.min(Math.max(t5349, t3306), t5353);
    let t5342 = t5354 * t5391;
    acc5334 += t5342;
  });
  let t608 = {
    "marginal": acc5206,
    "effective": t5273,
    "tax": acc5334
  };
  let acc5466 = 0.0;
  t5209.forEach((t5470, t5471) => {
    let t5498 = t5470["lo"];
    let t5511 = t5470["hi"];
    let t5523 = t5470["rate"];
    let t5481 = t5234 - t5498;
    let t5504 = t5511 == t3325;
    let t5507 = t5504 ? t3327 : t5511;
    let t5485 = t5507 - t5498;
    let t5486 = Math.min(Math.max(t5481, t3306), t5485);
    let t5474 = t5486 * t5523;
    acc5466 += t5474;
  });
  let t5460 = acc5466 + t3476;
  let t5462 = t5460 + t3518;
  let t5464 = t5462 + t3521;
  let t5457 = t5464 / t3346;
  let acc5562 = 0.0;
  t5209.forEach((t5566, t5567) => {
    let t5594 = t5566["lo"];
    let t5607 = t5566["hi"];
    let t5619 = t5566["rate"];
    let t5577 = t5234 - t5594;
    let t5600 = t5607 == t3325;
    let t5603 = t5600 ? t3327 : t5607;
    let t5581 = t5603 - t5594;
    let t5582 = Math.min(Math.max(t5577, t3306), t5581);
    let t5570 = t5582 * t5619;
    acc5562 += t5570;
  });
  let t5556 = acc5562 + t3476;
  let t5558 = t5556 + t3518;
  let t5560 = t5558 + t3521;
  let t622 = {
    "effective": t5457,
    "tax": t5560
  };
  let acc5661 = 0.0;
  t5209.forEach((t5665, t5666) => {
    let t5693 = t5665["lo"];
    let t5706 = t5665["hi"];
    let t5718 = t5665["rate"];
    let t5676 = t5234 - t5693;
    let t5699 = t5706 == t3325;
    let t5702 = t5699 ? t3327 : t5706;
    let t5680 = t5702 - t5693;
    let t5681 = Math.min(Math.max(t5676, t3306), t5680);
    let t5669 = t5681 * t5718;
    acc5661 += t5669;
  });
  let t5655 = acc5661 + t3476;
  let t5657 = t5655 + t3518;
  let t5659 = t5657 + t3521;
  let t5652 = t3301 - t5659;
  let acc5763 = 0.0;
  t5209.forEach((t5767, t5768) => {
    let t5795 = t5767["lo"];
    let t5808 = t5767["hi"];
    let t5820 = t5767["rate"];
    let t5778 = t5234 - t5795;
    let t5801 = t5808 == t3325;
    let t5804 = t5801 ? t3327 : t5808;
    let t5782 = t5804 - t5795;
    let t5783 = Math.min(Math.max(t5778, t3306), t5782);
    let t5771 = t5783 * t5820;
    acc5763 += t5771;
  });
  let t5757 = acc5763 + t3476;
  let t5759 = t5757 + t3518;
  let t5761 = t5759 + t3521;
  let t5754 = t3301 - t5761;
  let t5751 = t5754 - t558;
  let t626 = {
    "federal": t608,
    "fica": t545,
    "state": t549,
    "local": t553,
    "total": t622,
    "after_tax": t5652,
    "retirement_contrib": t558,
    "take_home": t5751
  };
  let t627 = {
    "single": t560,
    "married_joint": t582,
    "married_separate": t604,
    "head_of_household": t626
  };
  return t627;
}

