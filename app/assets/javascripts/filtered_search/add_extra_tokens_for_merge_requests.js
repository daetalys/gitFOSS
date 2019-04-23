export default IssuableTokenKeys => {
  const wipToken = {
    key: 'wip',
    type: 'string',
    param: '',
    symbol: '',
    icon: 'admin',
    tag: 'Yes or No',
    lowercaseValueOnSubmit: true,
    uppercaseTokenName: true,
    capitalizeTokenValue: true,
  };

  IssuableTokenKeys.tokenKeys.push(wipToken);
  IssuableTokenKeys.tokenKeysWithAlternative.push(wipToken);

  const targetBranchToken = {
    key: 'target-branch',
    type: 'string',
    param: '',
    symbol: '',
    icon: 'arrow-right',
    tag: 'branch',
  };

  IssuableTokenKeys.tokenKeys.push(targetBranchToken);
  IssuableTokenKeys.tokenKeysWithAlternative.push(targetBranchToken);
};
